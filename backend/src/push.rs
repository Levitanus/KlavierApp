use actix_web::{post, web, HttpRequest, HttpResponse, Result};
use chrono::{DateTime, Duration, Utc};
use jsonwebtoken::{EncodingKey, Header};
use log::{debug, error, info, warn};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::env;
use std::fs;
use std::sync::OnceLock;
use tokio::sync::Mutex;

use crate::notifications::{ContentBlock, NotificationBody};
use crate::users::verify_token;
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct RegisterPushTokenRequest {
    pub token: String,
    pub platform: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RevokePushTokenRequest {
    pub token: String,
}

#[derive(Debug, Deserialize)]
struct ServiceAccountKey {
    project_id: String,
    private_key: String,
    client_email: String,
    token_uri: String,
}

#[derive(Debug, Serialize)]
struct TokenRequest<'a> {
    iss: &'a str,
    sub: &'a str,
    aud: &'a str,
    iat: i64,
    exp: i64,
    scope: &'a str,
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: i64,
}

#[derive(Debug)]
struct CachedAccessToken {
    token: String,
    expires_at: DateTime<Utc>,
}

static SERVICE_ACCOUNT: OnceLock<Option<ServiceAccountKey>> = OnceLock::new();
static ACCESS_TOKEN: OnceLock<Mutex<Option<CachedAccessToken>>> = OnceLock::new();

fn load_service_account() -> Option<&'static ServiceAccountKey> {
    SERVICE_ACCOUNT
        .get_or_init(|| {
            let path = match env::var("FCM_SERVICE_ACCOUNT_PATH") {
                Ok(value) => {
                    debug!("FCM_SERVICE_ACCOUNT_PATH is set: {}", value);
                    value
                }
                Err(_) => {
                    warn!("FCM_SERVICE_ACCOUNT_PATH is not set; push delivery disabled");
                    return None;
                }
            };

            let contents = match fs::read_to_string(&path) {
                Ok(value) => {
                    info!("Successfully loaded service account file from: {}", path);
                    value
                }
                Err(err) => {
                    warn!("Failed to read service account file at {}: {}", path, err);
                    return None;
                }
            };

            match serde_json::from_str::<ServiceAccountKey>(&contents) {
                Ok(value) => {
                    info!("Service account parsed successfully for project: {}", value.project_id);
                    Some(value)
                }
                Err(err) => {
                    warn!("Failed to parse service account JSON: {}", err);
                    None
                }
            }
        })
        .as_ref()
}

async fn get_access_token(service_account: &ServiceAccountKey) -> Result<String> {
    let cache = ACCESS_TOKEN.get_or_init(|| Mutex::new(None));
    {
        let guard = cache.lock().await;
        if let Some(cached) = guard.as_ref() {
            if cached.expires_at > Utc::now() + Duration::seconds(30) {
                debug!("Using cached FCM access token (expires at {})", cached.expires_at);
                return Ok(cached.token.clone());
            }
        }
    }

    debug!("Requesting new FCM access token...");
    let now = Utc::now();
    let token_request = TokenRequest {
        iss: &service_account.client_email,
        sub: &service_account.client_email,
        aud: &service_account.token_uri,
        iat: now.timestamp(),
        exp: (now + Duration::minutes(55)).timestamp(),
        scope: "https://www.googleapis.com/auth/firebase.messaging",
    };

    let header = Header::new(jsonwebtoken::Algorithm::RS256);
    let key = EncodingKey::from_rsa_pem(service_account.private_key.as_bytes())
        .map_err(|e| {
            error!("Failed to create encoding key: {}", e);
            actix_web::error::ErrorInternalServerError("Invalid FCM credentials")
        })?;

    let assertion = jsonwebtoken::encode(&header, &token_request, &key)
        .map_err(|e| {
            error!("Failed to sign JWT: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to authenticate FCM")
        })?;

    let client = reqwest::Client::new();
    debug!("Sending JWT assertion to FCM token endpoint: {}", service_account.token_uri);
    let response = client
        .post(&service_account.token_uri)
        .form(&[
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            ("assertion", assertion.as_str()),
        ])
        .send()
        .await
        .map_err(|e| {
            error!("Failed to request access token: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to authenticate FCM")
        })?;

    let status = response.status();
    if !status.is_success() {
        let body = response.text().await.unwrap_or_default();
        error!("FCM token request failed: {} {}", status, body);
        return Err(actix_web::error::ErrorInternalServerError(
            "Failed to authenticate FCM",
        ));
    }

    info!("FCM access token obtained successfully");
    let token_response = response.json::<TokenResponse>().await.map_err(|e| {
        error!("Failed to parse access token: {}", e);
        actix_web::error::ErrorInternalServerError("Failed to authenticate FCM")
    })?;

    let expires_at = Utc::now() + Duration::seconds(token_response.expires_in);
    let cached = CachedAccessToken {
        token: token_response.access_token.clone(),
        expires_at,
    };

    let mut guard = cache.lock().await;
    *guard = Some(cached);

    Ok(token_response.access_token)
}

fn notification_preview(body: &NotificationBody) -> String {
    for block in &body.content.blocks {
        if let ContentBlock::Text { text, .. } = block {
            if !text.trim().is_empty() {
                return text.clone();
            }
        }
    }

    body.title.clone()
}

enum SendOutcome {
    Delivered,
    Unregistered,
}

async fn send_fcm_message(
    service_account: &ServiceAccountKey,
    access_token: &str,
    token: &str,
    body: &NotificationBody,
    notification_id: Option<i32>,
) -> Result<SendOutcome> {
    debug!("[FCM] Preparing message for token: {}... (type: {})", 
        &token[..token.len().min(20)], body.body_type);
    
    let preview = notification_preview(body);

    #[derive(Serialize)]
    struct FcmMessage<'a> {
        message: FcmMessageBody<'a>,
    }

    #[derive(Serialize)]
    struct FcmMessageBody<'a> {
        token: &'a str,
        notification: FcmNotification<'a>,
        #[serde(skip_serializing_if = "Option::is_none")]
        data: Option<serde_json::Value>,
        #[serde(skip_serializing_if = "Option::is_none")]
        android: Option<FcmAndroid<'a>>,
    }

    #[derive(Serialize)]
    struct FcmNotification<'a> {
        title: &'a str,
        body: &'a str,
    }

    #[derive(Serialize)]
    struct FcmAndroid<'a> {
        notification: FcmAndroidNotification<'a>,
    }

    #[derive(Serialize)]
    struct FcmAndroidNotification<'a> {
        icon: &'a str,
        #[serde(skip_serializing_if = "Option::is_none")]
        color: Option<&'a str>,
    }

    let mut data_map = serde_json::Map::new();
    if let Some(route) = &body.route {
        data_map.insert("route".to_string(), serde_json::Value::String(route.clone()));
    }
    if let Some(id) = notification_id {
        data_map.insert(
            "notification_id".to_string(),
            serde_json::Value::String(id.to_string()),
        );
    }
    data_map.insert(
        "type".to_string(),
        serde_json::Value::String(body.body_type.clone()),
    );
    if let Some(metadata) = &body.metadata {
        data_map.insert(
            "metadata".to_string(),
            serde_json::Value::String(metadata.to_string()),
        );
    }

    let data = serde_json::Value::Object(data_map);

    let icon = if body.body_type == "chat_message" || body.body_type == "feed_comment" {
        "ic_notif_message"
    } else {
        "ic_notif_bell"
    };

    let payload = FcmMessage {
        message: FcmMessageBody {
            token,
            notification: FcmNotification {
                title: &body.title,
                body: &preview,
            },
            data: Some(data),
            android: Some(FcmAndroid {
                notification: FcmAndroidNotification {
                    icon,
                    color: Some("#c4161d"),
                },
            }),
        },
    };

    let url = format!(
        "https://fcm.googleapis.com/v1/projects/{}/messages:send",
        service_account.project_id
    );

    debug!("[FCM] Sending to: {}", url);
    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .bearer_auth(access_token)
        .json(&payload)
        .send()
        .await
        .map_err(|e| {
            error!("[FCM] Failed to send FCM message: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to send push")
        })?;

    if response.status().is_success() {
        info!("[FCM] Message sent successfully to token: {}...", &token[..token.len().min(20)]);
        return Ok(SendOutcome::Delivered);
    }

    let status = response.status();
    let body_text = response.text().await.unwrap_or_default();
    error!("[FCM] Send failed: {} {}", status, body_text);

    if body_text.contains("UNREGISTERED") || body_text.contains("NOT_FOUND") {
        warn!("[FCM] Token is unregistered: {}...", &token[..token.len().min(20)]);
        return Ok(SendOutcome::Unregistered);
    }

    Err(actix_web::error::ErrorInternalServerError("FCM send failed"))
}

async fn revoke_token(db: &PgPool, token: &str) {
    debug!("[FCM] Revoking token: {}...", &token[..token.len().min(20)]);
    let _ = sqlx::query(
        "UPDATE push_tokens SET revoked_at = NOW() WHERE token = $1 AND revoked_at IS NULL",
    )
    .bind(token)
    .execute(db)
    .await;
}

pub async fn send_notification_to_user(
    db: &PgPool,
    user_id: i32,
    body: &NotificationBody,
    notification_id: Option<i32>,
) {
    debug!("[PUSH] Attempting to send notification to user {} (type: {}, id: {:?})", 
        user_id, body.body_type, notification_id);
    
    let service_account = match load_service_account() {
        Some(account) => {
            debug!("[PUSH] Service account loaded");
            account
        }
        None => {
            warn!("[PUSH] Push skipped: missing service account");
            return;
        }
    };

    let tokens = match sqlx::query_scalar::<_, String>(
        "SELECT token FROM push_tokens WHERE user_id = $1 AND revoked_at IS NULL",
    )
    .bind(user_id)
    .fetch_all(db)
    .await
    {
        Ok(values) => {
            debug!("[PUSH] Loaded {} tokens for user {}", values.len(), user_id);
            values
        }
        Err(err) => {
            error!("[PUSH] Failed to load push tokens for user {}: {}", user_id, err);
            return;
        }
    };

    if tokens.is_empty() {
        warn!("[PUSH] Push skipped: no tokens for user {}", user_id);
        return;
    }

    let access_token = match get_access_token(service_account).await {
        Ok(token) => {
            debug!("[PUSH] Access token obtained");
            token
        }
        Err(_) => {
            error!("[PUSH] Failed to obtain access token");
            return;
        }
    };

    for token in tokens {
        match send_fcm_message(service_account, &access_token, &token, body, notification_id).await {
            Ok(SendOutcome::Delivered) => {
                debug!("[PUSH] Delivered to token: {}...", &token[..token.len().min(20)]);
            }
            Ok(SendOutcome::Unregistered) => {
                warn!("[PUSH] Token unregistered, revoking: {}...", &token[..token.len().min(20)]);
                revoke_token(db, &token).await;
            }
            Err(err) => {
                error!("[PUSH] FCM delivery failed: {:?}", err);
            }
        }
    }
}

#[post("/api/push/tokens")]
pub async fn register_token(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    payload: web::Json<RegisterPushTokenRequest>,
) -> Result<HttpResponse> {
    debug!("[PUSH] Registering token, platform: {:?}", payload.platform);
    
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => {
            debug!("[PUSH] Token verified for user: {}", claims.sub);
            claims
        }
        Err(_) => {
            error!("[PUSH] Invalid or missing JWT token");
            return Err(actix_web::error::ErrorUnauthorized("Invalid or missing token"));
        }
    };

    let user_id = sqlx::query_scalar::<_, i32>("SELECT id FROM users WHERE username = $1")
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await
        .map_err(|e| {
            error!("[PUSH] Failed to fetch user id for {}: {}", claims.sub, e);
            actix_web::error::ErrorInternalServerError("Failed to register push token")
        })?
        .ok_or_else(|| {
            error!("[PUSH] User not found: {}", claims.sub);
            actix_web::error::ErrorUnauthorized("User not found")
        })?;

    let platform = payload
        .platform
        .clone()
        .unwrap_or_else(|| "unknown".to_string());

    info!("[PUSH] Registering token for user {} (platform: {})", user_id, platform);

    sqlx::query(
        r#"
        INSERT INTO push_tokens (user_id, token, platform, last_seen_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (token) DO UPDATE
        SET user_id = EXCLUDED.user_id,
            platform = EXCLUDED.platform,
            last_seen_at = NOW(),
            revoked_at = NULL
        "#,
    )
    .bind(user_id)
    .bind(&payload.token)
    .bind(&platform)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("[PUSH] Failed to store token for user {}: {}", user_id, e);
        actix_web::error::ErrorInternalServerError("Failed to register push token")
    })?;

    info!("[PUSH] Successfully registered token for user {} (platform: {})", user_id, platform);
    Ok(HttpResponse::Ok().json(serde_json::json!({"ok": true})))
}

#[post("/api/push/tokens/revoke")]
pub async fn revoke_token_endpoint(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    payload: web::Json<RevokePushTokenRequest>,
) -> Result<HttpResponse> {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(_) => {
            return Err(actix_web::error::ErrorUnauthorized("Invalid or missing token"));
        }
    };

    let user_id = sqlx::query_scalar::<_, i32>("SELECT id FROM users WHERE username = $1")
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await
        .map_err(|e| {
            error!("Failed to fetch user id: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to revoke push token")
        })?
        .ok_or_else(|| actix_web::error::ErrorUnauthorized("User not found"))?;

    let result = sqlx::query(
        "UPDATE push_tokens SET revoked_at = NOW() WHERE user_id = $1 AND token = $2 AND revoked_at IS NULL",
    )
    .bind(user_id)
    .bind(&payload.token)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("Failed to revoke push token: {}", e);
        actix_web::error::ErrorInternalServerError("Failed to revoke push token")
    })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "revoked": result.rows_affected()
    })))
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(register_token).service(revoke_token_endpoint);
}
