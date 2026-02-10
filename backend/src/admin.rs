use actix_web::{get, post, put, delete, web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use argon2::{Argon2, PasswordHasher};
use argon2::password_hash::{SaltString, rand_core::OsRng};
use chrono::{DateTime, Utc};

use crate::AppState;
use crate::users::verify_token;
use crate::password_reset;

#[derive(Debug, Serialize, FromRow)]
pub struct UserResponse {
    pub id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    #[sqlx(skip)]
    pub roles: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub password: String,
    pub roles: Vec<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub username: Option<String>,
    pub password: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub roles: Option<Vec<String>>,
}

// Helper to verify admin role from claims
fn verify_admin_role(req: &HttpRequest, app_state: &AppState) -> Result<(), HttpResponse> {
    let claims = verify_token(req, app_state)?;
    
    if !claims.roles.contains(&"admin".to_string()) {
        return Err(HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Admin access required"
        })));
    }
    
    Ok(())
}

#[get("/users")]
async fn get_users(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    // Get all users with their roles
    let users_result = sqlx::query_as::<_, UserResponse>(
        "SELECT id, username, email, phone FROM users ORDER BY username"
    )
    .fetch_all(&app_state.db)
    .await;

    let mut users = match users_result {
        Ok(users) => users,
        Err(e) => {
            eprintln!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to fetch users"
            }));
        }
    };

    // Fetch roles for each user
    for user in &mut users {
        let roles_result = sqlx::query_scalar::<_, String>(
            "SELECT r.name FROM roles r 
             INNER JOIN user_roles ur ON r.id = ur.role_id 
             WHERE ur.user_id = $1"
        )
        .bind(user.id)
        .fetch_all(&app_state.db)
        .await;

        user.roles = roles_result.unwrap_or_default();
    }

    HttpResponse::Ok().json(users)
}

#[post("/users")]
async fn create_user(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_data: web::Json<CreateUserRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    // Hash password
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = match argon2.hash_password(user_data.password.as_bytes(), &salt) {
        Ok(hash) => hash.to_string(),
        Err(e) => {
            eprintln!("Password hashing error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to hash password"
            }));
        }
    };

    // Insert user
    let user_result = sqlx::query_scalar::<_, i32>(
        "INSERT INTO users (username, password_hash, email, phone) VALUES ($1, $2, $3, $4) RETURNING id"
    )
    .bind(&user_data.username)
    .bind(&password_hash)
    .bind(&user_data.email)
    .bind(&user_data.phone)
    .fetch_one(&app_state.db)
    .await;

    let user_id = match user_result {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create user"
            }));
        }
    };

    // Assign roles
    for role_name in &user_data.roles {
        let role_result = sqlx::query_scalar::<_, i32>(
            "SELECT id FROM roles WHERE name = $1"
        )
        .bind(role_name)
        .fetch_optional(&app_state.db)
        .await;

        if let Ok(Some(role_id)) = role_result {
            let _ = sqlx::query(
                "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
            )
            .bind(user_id)
            .bind(role_id)
            .execute(&app_state.db)
            .await;
        }
    }

    HttpResponse::Ok().json(serde_json::json!({
        "id": user_id,
        "username": user_data.username,
        "roles": user_data.roles
    }))
}

#[put("/users/{id}")]
async fn update_user(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
    user_data: web::Json<UpdateUserRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Update username if provided
    if let Some(username) = &user_data.username {
        let result = sqlx::query("UPDATE users SET username = $1 WHERE id = $2")
            .bind(username)
            .bind(user_id)
            .execute(&app_state.db)
            .await;

        if result.is_err() {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update username"
            }));
        }
    }

    // Update password if provided
    if let Some(password) = &user_data.password {
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();
        let password_hash = match argon2.hash_password(password.as_bytes(), &salt) {
            Ok(hash) => hash.to_string(),
            Err(_) => {
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to hash password"
                }));
            }
        };

        let result = sqlx::query("UPDATE users SET password_hash = $1 WHERE id = $2")
            .bind(&password_hash)
            .bind(user_id)
            .execute(&app_state.db)
            .await;

        if result.is_err() {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update password"
            }));
        }
    }

    // Update email if provided
    if let Some(email) = &user_data.email {
        let result = sqlx::query("UPDATE users SET email = $1 WHERE id = $2")
            .bind(email)
            .bind(user_id)
            .execute(&app_state.db)
            .await;

        if result.is_err() {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update email"
            }));
        }
    }

    // Update phone if provided
    if let Some(phone) = &user_data.phone {
        let result = sqlx::query("UPDATE users SET phone = $1 WHERE id = $2")
            .bind(phone)
            .bind(user_id)
            .execute(&app_state.db)
            .await;

        if result.is_err() {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update phone"
            }));
        }
    }

    // Update roles if provided
    if let Some(roles) = &user_data.roles {
        // Delete existing roles
        let _ = sqlx::query("DELETE FROM user_roles WHERE user_id = $1")
            .bind(user_id)
            .execute(&app_state.db)
            .await;

        // Insert new roles
        for role_name in roles {
            let role_result = sqlx::query_scalar::<_, i32>(
                "SELECT id FROM roles WHERE name = $1"
            )
            .bind(role_name)
            .fetch_optional(&app_state.db)
            .await;

            if let Ok(Some(role_id)) = role_result {
                let _ = sqlx::query(
                    "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
                )
                .bind(user_id)
                .bind(role_id)
                .execute(&app_state.db)
                .await;
            }
        }
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "User updated successfully"
    }))
}

#[delete("/users/{id}")]
async fn delete_user(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    let result = sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user_id)
        .execute(&app_state.db)
        .await;

    match result {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({
            "message": "User deleted successfully"
        })),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to delete user"
            }))
        }
    }
}

#[derive(Debug, Serialize)]
pub struct GenerateResetLinkResponse {
    pub reset_link: String,
    pub expires_at: String,
}

#[post("/users/{id}/generate-reset-link")]
async fn generate_reset_link(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Check if user exists
    let user_exists = sqlx::query_scalar::<_, bool>("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)")
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await;

    match user_exists {
        Ok(false) | Err(_) => {
            return HttpResponse::NotFound().json(serde_json::json!({
                "error": "User not found"
            }));
        }
        _ => {}
    }

    // Generate reset token
    match password_reset::generate_reset_token_for_user(&app_state.db, user_id).await {
        Ok(token) => {
            let reset_url_base = std::env::var("RESET_URL_BASE")
                .unwrap_or_else(|_| "http://localhost:8080/reset-password".to_string());
            let reset_link = format!("{}/{}", reset_url_base, token);
            
            HttpResponse::Ok().json(GenerateResetLinkResponse {
                reset_link,
                expires_at: "1 hour".to_string(),
            })
        }
        Err(e) => {
            eprintln!("Failed to generate reset token: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to generate reset link"
            }))
        }
    }
}

#[derive(Debug, Serialize, FromRow)]
pub struct PasswordResetRequestResponse {
    pub id: i32,
    pub username: String,
    pub requested_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
    pub resolved_by_admin_id: Option<i32>,
}

#[get("/password-reset-requests")]
async fn get_password_reset_requests(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    match password_reset::get_pending_requests(&app_state.db).await {
        Ok(requests) => {
            let responses: Vec<PasswordResetRequestResponse> = requests
                .into_iter()
                .map(|r| PasswordResetRequestResponse {
                    id: r.id,
                    username: r.username,
                    requested_at: r.requested_at,
                    resolved_at: r.resolved_at,
                    resolved_by_admin_id: r.resolved_by_admin_id,
                })
                .collect();
            
            HttpResponse::Ok().json(responses)
        }
        Err(e) => {
            eprintln!("Failed to fetch password reset requests: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to fetch password reset requests"
            }))
        }
    }
}

#[post("/password-reset-requests/{id}/resolve")]
async fn resolve_password_reset_request(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    request_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    // Get admin user ID from token
    let claims = match verify_token(&req, &app_state) {
        Ok(c) => c,
        Err(response) => return response,
    };

    let admin_id = match sqlx::query_scalar::<_, i32>("SELECT id FROM users WHERE username = $1")
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await
    {
        Ok(Some(id)) => id,
        _ => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to resolve admin user"
            }));
        }
    };

    match password_reset::resolve_request(&app_state.db, *request_id, admin_id).await {
        Ok(_) => {
            HttpResponse::Ok().json(serde_json::json!({
                "message": "Password reset request resolved"
            }))
        }
        Err(e) => {
            eprintln!("Failed to resolve password reset request: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to resolve password reset request"
            }))
        }
    }
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/admin")
            .service(get_users)
            .service(create_user)
            .service(update_user)
            .service(delete_user)
            .service(generate_reset_link)
            .service(get_password_reset_requests)
            .service(resolve_password_reset_request)
    );
}
