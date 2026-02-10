use actix_web::{post, get, web, HttpResponse, Responder, HttpRequest};
use actix_multipart::Multipart;
use futures_util::stream::StreamExt as _;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use jsonwebtoken::{encode, decode, EncodingKey, DecodingKey, Header, Validation};
use chrono::{Duration, Utc};
use argon2::{Argon2, PasswordHash, PasswordVerifier};
use std::io::Write;
use uuid::Uuid;

use crate::{AppState, password_reset};

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

#[derive(Debug, Serialize, Deserialize)]
pub struct ForgotPasswordRequest {
    pub username: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ForgotPasswordResponse {
    pub message: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ResetPasswordRequest {
    pub password: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ValidateTokenResponse {
    pub valid: bool,
    pub username: Option<String>,
}

#[post("/forgot-password")]
async fn forgot_password(
    app_state: web::Data<AppState>,
    req: web::Json<ForgotPasswordRequest>,
) -> impl Responder {
    match password_reset::request_password_reset(&app_state.db, &req.username, &app_state.email_service).await {
        Ok(_) => {
            HttpResponse::Ok().json(ForgotPasswordResponse {
                message: "If your username exists and has an email, you will receive a password reset link. Otherwise, an admin will be notified.".to_string(),
            })
        }
        Err(e) => {
            eprintln!("Password reset request error: {}", e);
            // Always return success to prevent username enumeration
            HttpResponse::Ok().json(ForgotPasswordResponse {
                message: "If your username exists and has an email, you will receive a password reset link. Otherwise, an admin will be notified.".to_string(),
            })
        }
    }
}

#[get("/reset-password/{token}")]
async fn validate_reset_token(
    app_state: web::Data<AppState>,
    token: web::Path<String>,
) -> impl Responder {
    match password_reset::verify_reset_token(&app_state.db, &token).await {
        Ok((_token_id, user_id)) => {
            // Fetch username
            let username = sqlx::query_scalar::<_, String>("SELECT username FROM users WHERE id = $1")
                .bind(user_id)
                .fetch_optional(&app_state.db)
                .await;
            
            match username {
                Ok(Some(username)) => {
                    HttpResponse::Ok().json(ValidateTokenResponse {
                        valid: true,
                        username: Some(username),
                    })
                }
                _ => {
                    HttpResponse::Ok().json(ValidateTokenResponse {
                        valid: false,
                        username: None,
                    })
                }
            }
        }
        Err(_) => {
            HttpResponse::Ok().json(ValidateTokenResponse {
                valid: false,
                username: None,
            })
        }
    }
}

#[post("/reset-password/{token}")]
async fn reset_password(
    app_state: web::Data<AppState>,
    token: web::Path<String>,
    req: web::Json<ResetPasswordRequest>,
) -> impl Responder {
    match password_reset::reset_password_with_token(&app_state.db, &token, &req.password).await {
        Ok(_) => {
            HttpResponse::Ok().json(serde_json::json!({
                "message": "Password reset successfully"
            }))
        }
        Err(e) => {
            eprintln!("Password reset error: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: format!("Failed to reset password: {}", e),
            })
        }
    }
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct UserProfile {
    pub id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub profile_image: Option<String>,
    #[serde(with = "chrono::serde::ts_seconds")]
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateProfileRequest {
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ChangePasswordRequest {
    pub current_password: String,
    pub new_password: String,
}

/// Get current user's profile
#[get("/profile")]
async fn get_profile(
    app_state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let profile_result = sqlx::query_as::<_, UserProfile>(
        "SELECT id, username, email, phone, profile_image, created_at FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await;

    match profile_result {
        Ok(Some(profile)) => HttpResponse::Ok().json(profile),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "User not found".to_string(),
        }),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            })
        }
    }
}

/// Update current user's profile
#[actix_web::put("/profile")]
async fn update_profile(
    app_state: web::Data<AppState>,
    req: HttpRequest,
    update_req: web::Json<UpdateProfileRequest>,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let update_result = sqlx::query(
        "UPDATE users SET email = $1, phone = $2 WHERE username = $3"
    )
    .bind(&update_req.email)
    .bind(&update_req.phone)
    .bind(&claims.sub)
    .execute(&app_state.db)
    .await;

    match update_result {
        Ok(_) => {
            // Fetch updated profile
            let profile_result = sqlx::query_as::<_, UserProfile>(
                "SELECT id, username, email, phone, profile_image, created_at FROM users WHERE username = $1"
            )
            .bind(&claims.sub)
            .fetch_optional(&app_state.db)
            .await;

            match profile_result {
                Ok(Some(profile)) => HttpResponse::Ok().json(profile),
                Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
                    error: "User not found".to_string(),
                }),
                Err(e) => {
                    eprintln!("Database error: {}", e);
                    HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "Internal server error".to_string(),
                    })
                }
            }
        }
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update profile".to_string(),
            })
        }
    }
}

/// Change current user's password
#[post("/profile/change-password")]
async fn change_password(
    app_state: web::Data<AppState>,
    req: HttpRequest,
    change_req: web::Json<ChangePasswordRequest>,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    // Verify current password first
    let user_result = sqlx::query_as::<_, User>(
        "SELECT id, username, password_hash FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await;

    let user = match user_result {
        Ok(Some(user)) => user,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "User not found".to_string(),
            });
        }
        Err(e) => {
            eprintln!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Verify current password
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
        .verify_password(change_req.current_password.as_bytes(), &parsed_hash)
        .is_ok();

    if !password_valid {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Current password is incorrect".to_string(),
        });
    }

    // Hash new password
    use argon2::{
        password_hash::{rand_core::OsRng, SaltString},
        PasswordHasher,
    };

    let salt = SaltString::generate(&mut OsRng);
    let new_hash = match Argon2::default().hash_password(change_req.new_password.as_bytes(), &salt) {
        Ok(hash) => hash.to_string(),
        Err(e) => {
            eprintln!("Failed to hash password: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to hash password".to_string(),
            });
        }
    };

    // Update password
    let update_result = sqlx::query(
        "UPDATE users SET password_hash = $1 WHERE username = $2"
    )
    .bind(&new_hash)
    .bind(&claims.sub)
    .execute(&app_state.db)
    .await;

    match update_result {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({
            "message": "Password changed successfully"
        })),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to change password".to_string(),
            })
        }
    }
}

/// Upload profile image
#[post("/profile/upload-image")]
async fn upload_profile_image(
    app_state: web::Data<AppState>,
    req: HttpRequest,
    mut payload: Multipart,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    // Get the uploaded file
    while let Some(item) = payload.next().await {
        let mut field = match item {
            Ok(field) => field,
            Err(e) => {
                eprintln!("Multipart error: {}", e);
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Failed to read upload".to_string(),
                });
            }
        };

        let content_disposition = field.content_disposition();
        if content_disposition.get_name() != Some("image") {
            continue;
        }

        // Get filename and extension
        let filename = content_disposition
            .get_filename()
            .unwrap_or("upload.jpg");
        
        let extension = std::path::Path::new(filename)
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("jpg");

        // Validate file type
        if !matches!(extension.to_lowercase().as_str(), "jpg" | "jpeg" | "png" | "gif" | "webp") {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Invalid file type. Only images are allowed.".to_string(),
            });
        }

        // Generate unique filename
        let unique_filename = format!("{}_{}.{}", claims.sub, Uuid::new_v4(), extension);
        let filepath = app_state.upload_dir.join(&unique_filename);

        // Create file and write data
        let mut f = match std::fs::File::create(&filepath) {
            Ok(file) => file,
            Err(e) => {
                eprintln!("Failed to create file: {}", e);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to save file".to_string(),
                });
            }
        };

        // Read and write chunks
        let mut file_size = 0u64;
        while let Some(chunk) = field.next().await {
            let data = match chunk {
                Ok(data) => data,
                Err(e) => {
                    eprintln!("Failed to read chunk: {}", e);
                    let _ = std::fs::remove_file(&filepath);
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "Failed to read upload".to_string(),
                    });
                }
            };

            file_size += data.len() as u64;
            if file_size > 5 * 1024 * 1024 {
                // 5MB limit
                let _ = std::fs::remove_file(&filepath);
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "File too large. Maximum size is 5MB.".to_string(),
                });
            }

            if let Err(e) = f.write_all(&data) {
                eprintln!("Failed to write file: {}", e);
                let _ = std::fs::remove_file(&filepath);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to save file".to_string(),
                });
            }
        }

        // Delete old profile image if exists
        let old_image_result = sqlx::query_scalar::<_, Option<String>>(
            "SELECT profile_image FROM users WHERE username = $1"
        )
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await;

        if let Ok(Some(Some(old_filename))) = old_image_result {
            if !old_filename.is_empty() {
                let old_path = app_state.upload_dir.join(&old_filename);
                let _ = std::fs::remove_file(old_path);
            }
        }

        // Update database with new filename
        let update_result = sqlx::query(
            "UPDATE users SET profile_image = $1 WHERE username = $2"
        )
        .bind(&unique_filename)
        .bind(&claims.sub)
        .execute(&app_state.db)
        .await;

        match update_result {
            Ok(_) => {
                return HttpResponse::Ok().json(serde_json::json!({
                    "filename": unique_filename,
                    "url": format!("/uploads/profile_images/{}", unique_filename)
                }));
            }
            Err(e) => {
                eprintln!("Database error: {}", e);
                let _ = std::fs::remove_file(&filepath);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to update profile".to_string(),
                });
            }
        }
    }

    HttpResponse::BadRequest().json(ErrorResponse {
        error: "No image uploaded".to_string(),
    })
}

/// Delete profile image
#[actix_web::delete("/profile/image")]
async fn delete_profile_image(
    app_state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    // Get current profile image
    let old_image_result = sqlx::query_scalar::<_, Option<String>>(
        "SELECT profile_image FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await;

    if let Ok(Some(Some(old_filename))) = old_image_result {
        if !old_filename.is_empty() {
            let old_path = app_state.upload_dir.join(&old_filename);
            let _ = std::fs::remove_file(old_path);
        }
    }

    // Update database
    let update_result = sqlx::query(
        "UPDATE users SET profile_image = NULL WHERE username = $1"
    )
    .bind(&claims.sub)
    .execute(&app_state.db)
    .await;

    match update_result {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({
            "message": "Profile image deleted"
        })),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to delete image".to_string(),
            })
        }
    }
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/auth")
            .service(login)
            .service(forgot_password)
            .service(validate_reset_token)
            .service(reset_password)
    );
    cfg.service(
        web::scope("/api")
            .service(get_profile)
            .service(update_profile)
            .service(change_password)
            .service(upload_profile_image)
            .service(delete_profile_image)
    );
}
