use actix_web::{get, post, put, delete, web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use argon2::{Argon2, PasswordHasher};
use argon2::password_hash::{SaltString, rand_core::OsRng};

use crate::AppState;
use crate::users::verify_token;

#[derive(Debug, Serialize, FromRow)]
pub struct UserResponse {
    pub id: i32,
    pub username: String,
    #[sqlx(skip)]
    pub roles: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub password: String,
    pub roles: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub username: Option<String>,
    pub password: Option<String>,
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
        "SELECT id, username FROM users ORDER BY username"
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
        "INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id"
    )
    .bind(&user_data.username)
    .bind(&password_hash)
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

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/admin")
            .service(get_users)
            .service(create_user)
            .service(update_user)
            .service(delete_user)
    );
}
