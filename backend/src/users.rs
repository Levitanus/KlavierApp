use actix_web::{post, web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use jsonwebtoken::{encode, decode, EncodingKey, DecodingKey, Header, Validation};
use chrono::{Duration, Utc};
use argon2::{Argon2, PasswordHash, PasswordVerifier};

use crate::AppState;

#[derive(Debug, Serialize, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LoginResponse {
    pub token: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ErrorResponse {
    pub error: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,      // username
    pub exp: usize,       // expiration time
    pub roles: Vec<String>, // user roles
}

/// Extract and validate JWT token from request
/// Returns Claims if valid, or an error HttpResponse
pub fn verify_token(req: &HttpRequest, app_state: &AppState) -> Result<Claims, HttpResponse> {
    let auth_header = req.headers().get("Authorization");
    
    let token = match auth_header {
        Some(header) => {
            let header_str = header.to_str().unwrap_or("");
            if header_str.starts_with("Bearer ") {
                &header_str[7..]
            } else {
                return Err(HttpResponse::Unauthorized().json(serde_json::json!({
                    "error": "Invalid authorization header"
                })));
            }
        }
        None => {
            return Err(HttpResponse::Unauthorized().json(serde_json::json!({
                "error": "Missing authorization header"
            })));
        }
    };

    let claims = match decode::<Claims>(
        token,
        &DecodingKey::from_secret(app_state.jwt_secret.as_ref()),
        &Validation::default(),
    ) {
        Ok(data) => data.claims,
        Err(_) => {
            return Err(HttpResponse::Unauthorized().json(serde_json::json!({
                "error": "Invalid token"
            })));
        }
    };

    Ok(claims)
}

#[derive(Debug, FromRow)]
struct User {
    #[allow(dead_code)]
    id: i32,
    username: String,
    password_hash: String,
}

#[post("/login")]
async fn login(
    app_state: web::Data<AppState>,
    credentials: web::Json<LoginRequest>,
) -> impl Responder {
    // Query user from database
    let user_result = sqlx::query_as::<_, User>(
        "SELECT id, username, password_hash FROM users WHERE username = $1"
    )
    .bind(&credentials.username)
    .fetch_optional(&app_state.db)
    .await;

    let user = match user_result {
        Ok(Some(user)) => user,
        Ok(None) => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid credentials".to_string(),
            });
        }
        Err(e) => {
            eprintln!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Verify password
    let parsed_hash = match PasswordHash::new(&user.password_hash) {
        Ok(hash) => hash,
        Err(e) => {
            eprintln!("Failed to parse password hash: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    let password_valid = Argon2::default()
        .verify_password(credentials.password.as_bytes(), &parsed_hash)
        .is_ok();

    if !password_valid {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid credentials".to_string(),
        });
    }

    // Fetch user roles
    let roles_result = sqlx::query_scalar::<_, String>(
        "SELECT r.name FROM roles r 
         INNER JOIN user_roles ur ON r.id = ur.role_id 
         WHERE ur.user_id = $1"
    )
    .bind(user.id)
    .fetch_all(&app_state.db)
    .await;

    let roles = match roles_result {
        Ok(roles) => roles,
        Err(e) => {
            eprintln!("Failed to fetch user roles: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Generate JWT token
    let expiration = Utc::now()
        .checked_add_signed(Duration::hours(24))
        .expect("valid timestamp")
        .timestamp() as usize;

    let claims = Claims {
        sub: user.username.clone(),
        exp: expiration,
        roles,
    };

    let token = match encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(app_state.jwt_secret.as_ref()),
    ) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("JWT encoding error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Could not generate token".to_string(),
            });
        }
    };

    HttpResponse::Ok().json(LoginResponse { token })
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/auth")
            .service(login)
    );
}
