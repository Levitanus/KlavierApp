use actix_web::{post, get, web, HttpResponse, Responder, HttpRequest};
use actix_multipart::Multipart;
use futures_util::stream::StreamExt as _;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use jsonwebtoken::{encode, decode, EncodingKey, DecodingKey, Header, Validation};
use chrono::{Duration, Utc, NaiveDate};
use argon2::{Argon2, PasswordHash, PasswordVerifier};
use log::{error};

use crate::{AppState, password_reset};
use crate::storage::{MediaError, MediaService};

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
            error!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Verify password
    let parsed_hash = match PasswordHash::new(&user.password_hash) {
        Ok(hash) => hash,
        Err(e) => {
            error!("Failed to parse password hash: {}", e);
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
            error!("Failed to fetch user roles: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Check if user has admin role OR at least one active activity role
    let has_admin = roles.contains(&"admin".to_string());
    
    if !has_admin {
        // Check if user has any active activity roles
        let mut has_active_role = false;
        
        // Check if student role is active
        if roles.contains(&"student".to_string()) {
            let is_active: Option<(bool,)> = sqlx::query_as(
                "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1 AND status = 'active')"
            )
            .bind(user.id)
            .fetch_optional(&app_state.db)
            .await
            .unwrap_or(None);
            
            if is_active.map(|(exists,)| exists).unwrap_or(false) {
                has_active_role = true;
            }
        }
        
        // Check if parent role is active
        if !has_active_role && roles.contains(&"parent".to_string()) {
            let is_active: Option<(bool,)> = sqlx::query_as(
                "SELECT EXISTS(SELECT 1 FROM parents WHERE user_id = $1 AND status = 'active')"
            )
            .bind(user.id)
            .fetch_optional(&app_state.db)
            .await
            .unwrap_or(None);
            
            if is_active.map(|(exists,)| exists).unwrap_or(false) {
                has_active_role = true;
            }
        }
        
        // Check if teacher role is active
        if !has_active_role && roles.contains(&"teacher".to_string()) {
            let is_active: Option<(bool,)> = sqlx::query_as(
                "SELECT EXISTS(SELECT 1 FROM teachers WHERE user_id = $1 AND status = 'active')"
            )
            .bind(user.id)
            .fetch_optional(&app_state.db)
            .await
            .unwrap_or(None);
            
            if is_active.map(|(exists,)| exists).unwrap_or(false) {
                has_active_role = true;
            }
        }
        
        if !has_active_role {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "All roles are archived".to_string(),
            });
        }
    }

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
            error!("JWT encoding error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Could not generate token".to_string(),
            });
        }
    };

    HttpResponse::Ok().json(LoginResponse { token })
}

#[get("/validate")]
async fn validate_token_endpoint(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let user_exists = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1",
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await;

    match user_exists {
        Ok(Some(_)) => HttpResponse::Ok().json(serde_json::json!({
            "valid": true,
            "username": claims.sub,
            "roles": claims.roles,
        })),
        Ok(None) => HttpResponse::Unauthorized().json(serde_json::json!({
            "error": "User not found",
        })),
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Internal server error",
            }))
        }
    }
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
            error!("Password reset request error: {}", e);
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
            error!("Password reset error: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: format!("Failed to reset password: {}", e),
            })
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StudentData {
    pub full_name: String,
    pub address: String,
    pub birthday: NaiveDate,
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ParentData {
    pub full_name: String,
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub children: Option<Vec<StudentInfo>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StudentInfo {
    pub user_id: i32,
    pub username: String,
    pub full_name: String,
    pub address: String,
    pub birthday: NaiveDate,
    pub profile_image: Option<String>,
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TeacherData {
    pub full_name: String,
    pub status: String,
}

#[derive(Debug, Serialize, FromRow)]
pub struct UserProfile {
    pub id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub profile_image: Option<String>,
    #[serde(with = "chrono::serde::ts_seconds")]
    pub created_at: chrono::DateTime<chrono::Utc>,
    #[sqlx(skip)]
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub roles: Vec<String>,
    #[sqlx(skip)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub student_data: Option<StudentData>,
    #[sqlx(skip)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_data: Option<ParentData>,
    #[sqlx(skip)]
    #[serde(skip_serializing_if = "Option::is_none")]
    pub teacher_data: Option<TeacherData>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateProfileRequest {
    pub email: Option<String>,
    pub phone: Option<String>,
    // Role-specific fields
    pub full_name: Option<String>,
    pub address: Option<String>,
    pub birthday: Option<String>, // YYYY-MM-DD format
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ChangePasswordRequest {
    pub current_password: String,
    pub new_password: String,
}

/// Get current user's profile
#[get("")]
async fn get_profile(
    app_state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let mut profile = match sqlx::query_as::<_, UserProfile>(
        "SELECT id, username, email, phone, profile_image, created_at FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(profile)) => profile,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "User not found".to_string(),
            });
        }
        Err(e) => {
            error!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Get user roles
    profile.roles = sqlx::query_scalar::<_, String>(
        "SELECT r.name FROM roles r 
         INNER JOIN user_roles ur ON r.id = ur.role_id 
         WHERE ur.user_id = $1"
    )
    .bind(profile.id)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default();

    // Get student data if user is a student
    if profile.roles.contains(&"student".to_string()) {
        if let Ok(Some((full_name, address, birthday, status))) = sqlx::query_as::<_, (String, String, NaiveDate, String)>(
            "SELECT full_name, address, birthday, status::text FROM students WHERE user_id = $1"
        )
        .bind(profile.id)
        .fetch_optional(&app_state.db)
        .await
        {
            profile.student_data = Some(StudentData {
                full_name,
                address,
                birthday,
                status,
            });
        }
    }

    // Get parent data if user is a parent
    if profile.roles.contains(&"parent".to_string()) {
        if let Ok(Some((full_name, status))) = sqlx::query_as::<_, (String, String)>(
            "SELECT full_name, status::text FROM parents WHERE user_id = $1"
        )
        .bind(profile.id)
        .fetch_optional(&app_state.db)
        .await
        {
            // Get children
            let children: Vec<_> = sqlx::query_as::<_, (i32, String, String, String, NaiveDate, Option<String>, String)>(
                "SELECT u.id, u.username, s.full_name, s.address, s.birthday, u.profile_image, s.status::text
                 FROM users u
                 INNER JOIN students s ON u.id = s.user_id
                 INNER JOIN parent_student_relations psr ON s.user_id = psr.student_user_id
                 WHERE psr.parent_user_id = $1"
            )
            .bind(profile.id)
            .fetch_all(&app_state.db)
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|(user_id, username, full_name, address, birthday, profile_image, status)| StudentInfo {
                user_id,
                username,
                full_name,
                address,
                birthday,
                profile_image,
                status,
            })
            .collect();

            profile.parent_data = Some(ParentData {
                full_name,
                status,
                children: if children.is_empty() { None } else { Some(children) },
            });
        }
    }

    // Get teacher data if user is a teacher
    if profile.roles.contains(&"teacher".to_string()) {
        if let Ok(Some((full_name, status))) = sqlx::query_as::<_, (String, String)>(
            "SELECT full_name, status::text FROM teachers WHERE user_id = $1"
        )
        .bind(profile.id)
        .fetch_optional(&app_state.db)
        .await
        {
            profile.teacher_data = Some(TeacherData { full_name, status });
        }
    }

    HttpResponse::Ok().json(profile)
}

/// Update current user's profile
#[actix_web::put("")]
async fn update_profile(
    app_state: web::Data<AppState>,
    req: HttpRequest,
    update_req: web::Json<UpdateProfileRequest>,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    // Get user ID
    let user_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(id)) => id,
        _ => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "User not found".to_string(),
            });
        }
    };

    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".to_string(),
            });
        }
    };

    // Update user table
    if let Err(e) = sqlx::query(
        "UPDATE users SET email = $1, phone = $2 WHERE id = $3"
    )
    .bind(&update_req.email)
    .bind(&update_req.phone)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to update user: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to update profile".to_string(),
        });
    }

    // Update role-specific data if provided
    if update_req.full_name.is_some() || update_req.address.is_some() || update_req.birthday.is_some() {
        // Check if user is a student
        let is_student = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1)"
        )
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await
        .unwrap_or(false);

        if is_student {
            let mut updates = Vec::new();
            let mut bind_count = 1;
            
            let birthday_date = if let Some(ref birthday_str) = update_req.birthday {
                match NaiveDate::parse_from_str(birthday_str, "%Y-%m-%d") {
                    Ok(date) => Some(date),
                    Err(_) => {
                        let _ = tx.rollback().await;
                        return HttpResponse::BadRequest().json(ErrorResponse {
                            error: "Invalid birthday format. Use YYYY-MM-DD".to_string(),
                        });
                    }
                }
            } else {
                None
            };

            if update_req.full_name.is_some() {
                updates.push(format!("full_name = ${}", bind_count));
                bind_count += 1;
            }
            if update_req.address.is_some() {
                updates.push(format!("address = ${}", bind_count));
                bind_count += 1;
            }
            if birthday_date.is_some() {
                updates.push(format!("birthday = ${}", bind_count));
                bind_count += 1;
            }

            if !updates.is_empty() {
                let query = format!(
                    "UPDATE students SET {} WHERE user_id = ${}",
                    updates.join(", "),
                    bind_count
                );

                let mut q = sqlx::query(&query);
                
                if let Some(ref full_name) = update_req.full_name {
                    q = q.bind(full_name);
                }
                if let Some(ref address) = update_req.address {
                    q = q.bind(address);
                }
                if let Some(date) = birthday_date {
                    q = q.bind(date);
                }
                q = q.bind(user_id);

                if let Err(e) = q.execute(&mut *tx).await {
                    error!("Failed to update student data: {}", e);
                    let _ = tx.rollback().await;
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "Failed to update student data".to_string(),
                    });
                }

                // Sync full_name to other role tables
                if let Some(ref full_name) = update_req.full_name {
                    let _ = sqlx::query("UPDATE parents SET full_name = $1 WHERE user_id = $2")
                        .bind(full_name)
                        .bind(user_id)
                        .execute(&mut *tx)
                        .await;
                    
                    let _ = sqlx::query("UPDATE teachers SET full_name = $1 WHERE user_id = $2")
                        .bind(full_name)
                        .bind(user_id)
                        .execute(&mut *tx)
                        .await;
                }
            }
        }

        // Update parent data if user is a parent and full_name provided
        if let Some(ref full_name) = update_req.full_name {
            let is_parent = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS(SELECT 1 FROM parents WHERE user_id = $1)"
            )
            .bind(user_id)
            .fetch_one(&mut *tx)
            .await
            .unwrap_or(false);

            if is_parent {
                if let Err(e) = sqlx::query(
                    "UPDATE parents SET full_name = $1 WHERE user_id = $2"
                )
                .bind(full_name)
                .bind(user_id)
                .execute(&mut *tx)
                .await
                {
                    error!("Failed to update parent data: {}", e);
                }

                // Sync to other role tables
                let _ = sqlx::query("UPDATE students SET full_name = $1 WHERE user_id = $2")
                    .bind(full_name)
                    .bind(user_id)
                    .execute(&mut *tx)
                    .await;
                
                let _ = sqlx::query("UPDATE teachers SET full_name = $1 WHERE user_id = $2")
                    .bind(full_name)
                    .bind(user_id)
                    .execute(&mut *tx)
                    .await;
            }
        }

        // Update teacher data if user is a teacher and full_name provided
        if let Some(ref full_name) = update_req.full_name {
            let is_teacher = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS(SELECT 1 FROM teachers WHERE user_id = $1)"
            )
            .bind(user_id)
            .fetch_one(&mut *tx)
            .await
            .unwrap_or(false);

            if is_teacher {
                if let Err(e) = sqlx::query(
                    "UPDATE teachers SET full_name = $1 WHERE user_id = $2"
                )
                .bind(full_name)
                .bind(user_id)
                .execute(&mut *tx)
                .await
                {
                    error!("Failed to update teacher data: {}", e);
                }

                // Sync to other role tables
                let _ = sqlx::query("UPDATE students SET full_name = $1 WHERE user_id = $2")
                    .bind(full_name)
                    .bind(user_id)
                    .execute(&mut *tx)
                    .await;
                
                let _ = sqlx::query("UPDATE parents SET full_name = $1 WHERE user_id = $2")
                    .bind(full_name)
                    .bind(user_id)
                    .execute(&mut *tx)
                    .await;
            }
        }
    }

    // Commit transaction
    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to save changes".to_string(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "Profile updated successfully"
    }))
}

/// Change current user's password
#[post("/change-password")]
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
            error!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Internal server error".to_string(),
            });
        }
    };

    // Verify current password
    let parsed_hash = match PasswordHash::new(&user.password_hash) {
        Ok(hash) => hash,
        Err(e) => {
            error!("Failed to parse password hash: {}", e);
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
            error!("Failed to hash password: {}", e);
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
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to change password".to_string(),
            })
        }
    }
}

/// Upload profile image
#[post("/upload-image")]
async fn upload_profile_image(
    app_state: web::Data<AppState>,
    req: HttpRequest,
    payload: Multipart,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let mut payload = payload;

    // Get the uploaded file
    while let Some(item) = payload.next().await {
        let field = match item {
            Ok(field) => field,
            Err(e) => {
                error!("Multipart error: {}", e);
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Failed to read upload".to_string(),
                });
            }
        };

        let extension = {
            let content_disposition = field.content_disposition();
            if content_disposition.get_name() != Some("image") {
                continue;
            }

            let filename = content_disposition.get_filename().unwrap_or("upload.jpg");

            let extension = std::path::Path::new(filename)
                .extension()
                .and_then(|ext| ext.to_str())
                .unwrap_or("jpg")
                .to_string();

            extension
        };

        let media_service = MediaService::new(app_state.storage.clone());
        let stream = field.map(|chunk| {
            chunk.map_err(|e| {
                std::io::Error::new(std::io::ErrorKind::Other, e.to_string())
            })
        });

        let stored = match media_service
            .save_profile_image(&claims.sub, &extension, stream)
            .await
        {
            Ok(stored) => stored,
            Err(MediaError::InvalidFileType) => {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Invalid file type. Only images are allowed.".to_string(),
                })
            }
            Err(MediaError::TooLarge) => {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "File too large. Maximum size is 5MB.".to_string(),
                })
            }
            Err(MediaError::Io(e)) => {
                error!("Failed to save file: {}", e);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to save file".to_string(),
                });
            }
        };

        // Delete old profile image if exists
        let old_image_result = sqlx::query_scalar::<_, Option<String>>(
            "SELECT profile_image FROM users WHERE username = $1"
        )
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await;

        if let Ok(Some(Some(old_filename))) = old_image_result {
            if !old_filename.is_empty() {
                if let Err(e) = media_service.delete_profile_image(&old_filename).await {
                    if let MediaError::Io(err) = e {
                        error!("Failed to delete old profile image: {}", err);
                    }
                }
            }
        }

        // Update database with new filename
        let update_result = sqlx::query(
            "UPDATE users SET profile_image = $1 WHERE username = $2"
        )
        .bind(&stored.key)
        .bind(&claims.sub)
        .execute(&app_state.db)
        .await;

        match update_result {
            Ok(_) => {
                return HttpResponse::Ok().json(serde_json::json!({
                    "filename": stored.key,
                    "url": stored.url
                }));
            }
            Err(e) => {
                error!("Database error: {}", e);
                let _ = media_service.delete_profile_image(&stored.key).await;
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
#[actix_web::delete("/image")]
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
            let media_service = MediaService::new(app_state.storage.clone());
            if let Err(e) = media_service.delete_profile_image(&old_filename).await {
                if let MediaError::Io(err) = e {
                    error!("Failed to delete profile image: {}", err);
                }
            }
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
            error!("Database error: {}", e);
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
            .service(validate_token_endpoint)
            .service(forgot_password)
            .service(validate_reset_token)
            .service(reset_password)
    );
    cfg.service(
        web::scope("/api/profile")
            .service(get_profile)
            .service(update_profile)
            .service(change_password)
            .service(upload_profile_image)
            .service(delete_profile_image)
    );
}
