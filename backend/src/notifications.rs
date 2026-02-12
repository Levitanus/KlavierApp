use actix_web::{web, HttpResponse, HttpRequest, Result};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use chrono::{DateTime, Utc};
use serde_json::Value as JsonValue;
use log::{error};

use crate::AppState;
use crate::users::verify_token;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Notification {
    pub id: i32,
    pub user_id: i32,
    #[serde(rename = "type")]
    pub notification_type: String,
    pub title: String,
    pub body: JsonValue,
    pub created_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
    pub priority: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateNotification {
    pub user_id: i32,
    #[serde(rename = "type")]
    pub notification_type: String,
    pub title: String,
    pub body: NotificationBody,
    pub priority: Option<String>,
}

/// Structured notification body format
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct NotificationBody {
    #[serde(rename = "type")]
    pub body_type: String, // e.g., "task_assigned", "password_issued"
    pub title: String,
    pub route: Option<String>, // Frontend route to navigate to
    pub content: NotificationContent,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<JsonValue>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct NotificationContent {
    pub blocks: Vec<ContentBlock>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub actions: Option<Vec<ActionButton>>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(tag = "type")]
pub enum ContentBlock {
    #[serde(rename = "text")]
    Text {
        text: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        style: Option<String>, // "body", "caption", "title", "subtitle"
    },
    #[serde(rename = "image")]
    Image {
        url: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        alt: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        width: Option<i32>,
        #[serde(skip_serializing_if = "Option::is_none")]
        height: Option<i32>,
    },
    #[serde(rename = "divider")]
    Divider,
    #[serde(rename = "spacer")]
    Spacer {
        #[serde(skip_serializing_if = "Option::is_none")]
        height: Option<i32>, // Height in pixels
    },
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ActionButton {
    pub label: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub route: Option<String>, // Frontend route
    #[serde(skip_serializing_if = "Option::is_none")]
    pub action: Option<String>, // e.g., "dismiss", "archive"
    #[serde(default)]
    pub primary: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct NotificationQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    pub unread_only: Option<bool>,
    #[serde(rename = "type")]
    pub notification_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct MarkAsReadRequest {
    pub notification_ids: Vec<i32>,
}

/// Get notifications for the authenticated user
pub async fn get_notifications(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    query: web::Query<NotificationQuery>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    
    let limit = query.limit.unwrap_or(50).min(100);
    let offset = query.offset.unwrap_or(0);
    
    let mut query_builder = sqlx::QueryBuilder::new(
        "SELECT id, user_id, type as notification_type, title, body, created_at, read_at, priority 
         FROM notifications WHERE user_id = "
    );
    query_builder.push_bind(user_id);
    
    if let Some(true) = query.unread_only {
        query_builder.push(" AND read_at IS NULL");
    }
    
    if let Some(ref notification_type) = query.notification_type {
        query_builder.push(" AND type = ");
        query_builder.push_bind(notification_type);
    }
    
    query_builder.push(" ORDER BY created_at DESC LIMIT ");
    query_builder.push_bind(limit);
    query_builder.push(" OFFSET ");
    query_builder.push_bind(offset);
    
    let notifications = query_builder
        .build_query_as::<Notification>()
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching notifications: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch notifications")
        })?;
    
    Ok(HttpResponse::Ok().json(notifications))
}

/// Mark notifications as read
pub async fn mark_as_read(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    payload: web::Json<MarkAsReadRequest>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    
    let result = sqlx::query(
        r#"
        UPDATE notifications 
        SET read_at = NOW()
        WHERE id = ANY($1) AND user_id = $2 AND read_at IS NULL
        "#
    )
    .bind(&payload.notification_ids)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error marking notifications as read: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark notifications as read")
    })?;
    
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "marked_as_read": result.rows_affected()
    })))
}

/// Get unread notification count
pub async fn get_unread_count(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    
    let count = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL"
    )
    .bind(user_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error getting unread count: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to get unread count")
    })?;
    
    Ok(HttpResponse::Ok().json(serde_json::json!({
        "unread_count": count
    })))
}

/// Create a new notification (typically called internally or by admins)
pub async fn create_notification(
    db: web::Data<PgPool>,
    payload: web::Json<CreateNotification>,
) -> Result<HttpResponse> {
    // Check if target user has admin role or any active activity role
    let role_statuses: (bool, bool, bool, bool, bool) = sqlx::query_as(
        "SELECT
            EXISTS(SELECT 1 FROM users u WHERE u.id = $1) AS user_exists,
            EXISTS(
                SELECT 1 FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = $1 AND r.name = 'admin'
            ) AS is_admin,
            EXISTS(SELECT 1 FROM students s WHERE s.user_id = $1 AND s.status = 'active') AS has_active_student,
            EXISTS(SELECT 1 FROM parents p WHERE p.user_id = $1 AND p.status = 'active') AS has_active_parent,
            EXISTS(SELECT 1 FROM teachers t WHERE t.user_id = $1 AND t.status = 'active') AS has_active_teacher"
    )
    .bind(payload.user_id)
    .fetch_one(db.get_ref())
    .await
    .map_err(|e| {
        error!("Database error checking role status: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to verify user")
    })?;

    let (user_exists, is_admin, has_active_student, has_active_parent, has_active_teacher) = role_statuses;

    if !user_exists {
        return Err(actix_web::error::ErrorNotFound("User not found"));
    }

    if !(is_admin || has_active_student || has_active_parent || has_active_teacher) {
        return Err(actix_web::error::ErrorBadRequest(
            "Cannot create notification for user without active roles"
        ));
    }

    let body_json = serde_json::to_value(&payload.body)
        .map_err(|e| {
            error!("Failed to serialize notification body: {:?}", e);
            actix_web::error::ErrorBadRequest("Invalid notification body format")
        })?;
    
    let notification = sqlx::query_as::<_, Notification>(
        r#"
        INSERT INTO notifications (user_id, type, title, body, priority)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, user_id, type as notification_type, title, body, created_at, read_at, priority
        "#
    )
    .bind(payload.user_id)
    .bind(&payload.notification_type)
    .bind(&payload.title)
    .bind(body_json)
    .bind(payload.priority.as_ref().unwrap_or(&"normal".to_string()))
    .fetch_one(db.get_ref())
    .await
    .map_err(|e| {
        error!("Database error creating notification: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create notification")
    })?;
    
    Ok(HttpResponse::Created().json(notification))
}

/// Delete a notification
pub async fn delete_notification(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    notification_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    
    let result = sqlx::query(
        "DELETE FROM notifications WHERE id = $1 AND user_id = $2"
    )
    .bind(*notification_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error deleting notification: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete notification")
    })?;
    
    if result.rows_affected() > 0 {
        Ok(HttpResponse::Ok().json(serde_json::json!({"deleted": true})))
    } else {
        Ok(HttpResponse::NotFound().json(serde_json::json!({"error": "Notification not found"})))
    }
}

/// Extract user_id from JWT token
async fn extract_user_id_from_token(req: &HttpRequest, app_state: &AppState) -> Result<i32> {
    // Verify JWT token and get claims
    let claims = match verify_token(req, app_state) {
        Ok(claims) => claims,
        Err(_response) => return Err(actix_web::error::ErrorUnauthorized("Invalid or missing token")),
    };
    
    // Get user_id from database using username from claims
    let user_id = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error getting user_id: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to get user information")
    })?
    .ok_or_else(|| actix_web::error::ErrorUnauthorized("User not found"))?;
    
    Ok(user_id)
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/notifications")
            .route("", web::get().to(get_notifications))
            .route("", web::post().to(create_notification))
            .route("/unread-count", web::get().to(get_unread_count))
            .route("/mark-read", web::post().to(mark_as_read))
            .route("/{id}", web::delete().to(delete_notification))
    );
}
