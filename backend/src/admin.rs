use actix_web::{get, post, put, delete, web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use argon2::{Argon2, PasswordHasher};
use argon2::password_hash::{SaltString, rand_core::OsRng};
use chrono::{DateTime, Utc, NaiveDate};
use log::{debug, error};

use crate::AppState;
use crate::users::verify_token;
use crate::password_reset;

#[derive(Debug, Serialize, FromRow)]
pub struct UserResponse {
    pub id: i32,
    pub username: String,
    pub full_name: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    #[sqlx(skip)]
    pub roles: Vec<String>,
    #[sqlx(skip)]
    pub student_status: Option<String>,
    #[sqlx(skip)]
    pub parent_status: Option<String>,
    #[sqlx(skip)]
    pub teacher_status: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub password: String,
    pub roles: Vec<String>,
    pub full_name: String,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub username: Option<String>,
    pub password: Option<String>,
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub roles: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
pub struct UsersQuery {
    pub search: Option<String>,
    pub page: Option<i64>,
    pub page_size: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct UsersPageResponse {
    pub users: Vec<UserResponse>,
    pub total: i64,
    pub page: i64,
    pub page_size: i64,
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

#[get("/api/admin/test")]
async fn test_route() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({
        "message": "Admin routes are working!"
    }))
}

#[get("/api/admin/users")]
async fn get_users(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    query: web::Query<UsersQuery>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let page = query.page.unwrap_or(1).max(1);
    let page_size = query.page_size.unwrap_or(20).clamp(1, 100);
    let offset = (page - 1) * page_size;
    let search = query
        .search
        .as_ref()
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(|value| value.to_string());

    let total_result: Result<i64, sqlx::Error> = if let Some(search) = &search {
        let pattern = format!("%{}%", search);
        sqlx::query_scalar(
            "SELECT COUNT(*) FROM users WHERE username ILIKE $1 OR full_name ILIKE $1",
        )
        .bind(pattern)
        .fetch_one(&app_state.db)
        .await
    } else {
        sqlx::query_scalar("SELECT COUNT(*) FROM users")
            .fetch_one(&app_state.db)
            .await
    };

    let total = match total_result {
        Ok(total) => total,
        Err(e) => {
            error!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to fetch users"
            }));
        }
    };

    let users_result = if let Some(search) = &search {
        let pattern = format!("%{}%", search);
        sqlx::query_as::<_, UserResponse>(
            "SELECT id, username, full_name, email, phone FROM users \
             WHERE username ILIKE $1 OR full_name ILIKE $1 \
             ORDER BY username LIMIT $2 OFFSET $3",
        )
        .bind(pattern)
        .bind(page_size)
        .bind(offset)
        .fetch_all(&app_state.db)
        .await
    } else {
        sqlx::query_as::<_, UserResponse>(
            "SELECT id, username, full_name, email, phone FROM users \
             ORDER BY username LIMIT $1 OFFSET $2",
        )
        .bind(page_size)
        .bind(offset)
        .fetch_all(&app_state.db)
        .await
    };

    let mut users = match users_result {
        Ok(users) => users,
        Err(e) => {
            error!("Database error: {}", e);
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

        if user.roles.contains(&"student".to_string()) {
            let status: Option<String> = sqlx::query_scalar(
                "SELECT status::text FROM students WHERE user_id = $1"
            )
            .bind(user.id)
            .fetch_optional(&app_state.db)
            .await
            .unwrap_or(None);

            user.student_status = status;
        }

        if user.roles.contains(&"parent".to_string()) {
            let status: Option<String> = sqlx::query_scalar(
                "SELECT status::text FROM parents WHERE user_id = $1"
            )
            .bind(user.id)
            .fetch_optional(&app_state.db)
            .await
            .unwrap_or(None);

            user.parent_status = status;
        }

        if user.roles.contains(&"teacher".to_string()) {
            let status: Option<String> = sqlx::query_scalar(
                "SELECT status::text FROM teachers WHERE user_id = $1"
            )
            .bind(user.id)
            .fetch_optional(&app_state.db)
            .await
            .unwrap_or(None);

            user.teacher_status = status;
        }
    }

    HttpResponse::Ok().json(UsersPageResponse {
        users,
        total,
        page,
        page_size,
    })
}

#[post("/api/admin/users")]
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
            error!("Password hashing error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to hash password"
            }));
        }
    };

    // Insert user
    let user_result = sqlx::query_scalar::<_, i32>(
        "INSERT INTO users (username, full_name, password_hash, email, phone) VALUES ($1, $2, $3, $4, $5) RETURNING id"
    )
    .bind(&user_data.username)
    .bind(&user_data.full_name)
    .bind(&password_hash)
    .bind(&user_data.email)
    .bind(&user_data.phone)
    .fetch_one(&app_state.db)
    .await;

    let user_id = match user_result {
        Ok(id) => id,
        Err(e) => {
            error!("Database error: {}", e);
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

#[put("/api/admin/users/{id}")]
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
        // Update full name if provided
        if let Some(full_name) = &user_data.full_name {
            let result = sqlx::query("UPDATE users SET full_name = $1 WHERE id = $2")
                .bind(full_name)
                .bind(user_id)
                .execute(&app_state.db)
                .await;

            if result.is_err() {
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to update full name"
                }));
            }
        }
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

#[delete("/api/admin/users/{id}")]
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
            error!("Database error: {}", e);
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

#[post("/api/admin/users/{id}/generate-reset-link")]
async fn generate_reset_link(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let _claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

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
            error!("Failed to generate reset token: {}", e);
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

#[get("/api/admin/password-reset-requests")]
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
            error!("Failed to fetch password reset requests: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to fetch password reset requests"
            }))
        }
    }
}

#[post("/api/admin/password-reset-requests/{id}/resolve")]
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
            error!("Failed to resolve password reset request: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to resolve password reset request"
            }))
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct MakeStudentRequest {
    pub birthday: String, // YYYY-MM-DD format
}

#[derive(Debug, Deserialize)]
pub struct MakeParentRequest {
    pub student_ids: Vec<i32>, // At least one required
}

#[derive(Debug, Deserialize)]
pub struct MakeTeacherRequest {
}

/// Convert an existing user to a student
#[post("/api/admin/users/{id}/make-student")]
async fn make_student(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
    student_data: web::Json<MakeStudentRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Parse birthday
    let birthday = match NaiveDate::parse_from_str(&student_data.birthday, "%Y-%m-%d") {
        Ok(date) => date,
        Err(_) => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Invalid birthday format. Use YYYY-MM-DD"
            }));
        }
    };

    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    // Check if user exists
    let user_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await;

    if !user_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "User not found"
        }));
    }

    // Check if already a student
    let is_student = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await;

    if is_student.unwrap_or(false) {
        return HttpResponse::Conflict().json(serde_json::json!({
            "error": "User is already a student"
        }));
    }

    // Get student role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = 'student'"
    )
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to get student role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Student role not found"
            }));
        }
    };

    // Check if user already has the role
    let has_role = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM user_roles WHERE user_id = $1 AND role_id = $2)"
    )
    .bind(user_id)
    .bind(role_id)
    .fetch_one(&mut *tx)
    .await
    .unwrap_or(false);

    // Assign student role if not already assigned
    if !has_role {
        if let Err(e) = sqlx::query(
            "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
        )
        .bind(user_id)
        .bind(role_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to assign role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to assign role"
            }));
        }
    }

    // Create student entry
    if let Err(e) = sqlx::query(
        "INSERT INTO students (user_id, birthday) 
         VALUES ($1, $2)"
    )
    .bind(user_id)
    .bind(birthday)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to create student entry: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create student"
        }));
    }

    // Commit transaction
    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "User converted to student successfully"
    }))
}

/// Convert an existing user to a parent
#[post("/api/admin/users/{id}/make-parent")]
async fn make_parent(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
    parent_data: web::Json<MakeParentRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Validate at least one student
    if parent_data.student_ids.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "At least one student is required"
        }));
    }

    // Prevent self-parenting
    if parent_data.student_ids.contains(&user_id) {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "A user cannot be their own parent"
        }));
    }

    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    // Check if user exists
    let user_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await;

    if !user_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "User not found"
        }));
    }

    // Check if already a parent
    let is_parent = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM parents WHERE user_id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await;

    if is_parent.unwrap_or(false) {
        return HttpResponse::Conflict().json(serde_json::json!({
            "error": "User is already a parent"
        }));
    }

    // Get parent role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = 'parent'"
    )
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to get parent role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Parent role not found"
            }));
        }
    };

    // Check if user already has the role
    let has_role = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM user_roles WHERE user_id = $1 AND role_id = $2)"
    )
    .bind(user_id)
    .bind(role_id)
    .fetch_one(&mut *tx)
    .await
    .unwrap_or(false);

    // Assign parent role if not already assigned
    if !has_role {
        if let Err(e) = sqlx::query(
            "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
        )
        .bind(user_id)
        .bind(role_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to assign role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to assign role"
            }));
        }
    }

    // Create parent entry
    if let Err(e) = sqlx::query(
        "INSERT INTO parents (user_id) VALUES ($1)"
    )
    .bind(user_id)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to create parent entry: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create parent"
        }));
    }

    // Create parent-student relations
    for student_id in &parent_data.student_ids {
        // Verify student exists
        let student_exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1)"
        )
        .bind(student_id)
        .fetch_one(&mut *tx)
        .await;

        if !student_exists.unwrap_or(false) {
            let _ = tx.rollback().await;
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": format!("Student with ID {} not found", student_id)
            }));
        }

        if let Err(e) = sqlx::query(
            "INSERT INTO parent_student_relations (parent_user_id, student_user_id) 
             VALUES ($1, $2) ON CONFLICT DO NOTHING"
        )
        .bind(user_id)
        .bind(student_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to create relation: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create parent-student relation"
            }));
        }
    }

    // Commit transaction
    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "User converted to parent successfully"
    }))
}

/// Convert an existing user to a teacher
#[post("/api/admin/users/{id}/make-teacher")]
async fn make_teacher(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
    _teacher_data: web::Json<MakeTeacherRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    // Check if user exists
    let user_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await;

    if !user_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "User not found"
        }));
    }

    // Check if already a teacher
    let is_teacher = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM teachers WHERE user_id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await;

    if is_teacher.unwrap_or(false) {
        return HttpResponse::Conflict().json(serde_json::json!({
            "error": "User is already a teacher"
        }));
    }

    // Get teacher role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = 'teacher'"
    )
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to get teacher role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Teacher role not found"
            }));
        }
    };

    // Check if user already has the role
    let has_role = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM user_roles WHERE user_id = $1 AND role_id = $2)"
    )
    .bind(user_id)
    .bind(role_id)
    .fetch_one(&mut *tx)
    .await
    .unwrap_or(false);

    // Assign teacher role if not already assigned
    if !has_role {
        if let Err(e) = sqlx::query(
            "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
        )
        .bind(user_id)
        .bind(role_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to assign role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to assign role"
            }));
        }
    }

    // Create teacher entry
    if let Err(e) = sqlx::query(
        "INSERT INTO teachers (user_id) VALUES ($1)"
    )
    .bind(user_id)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to create teacher entry: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create teacher"
        }));
    }

    // Create teacher feed if missing
    let has_feed = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM feeds WHERE owner_type = 'teacher' AND owner_user_id = $1)"
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await
    .unwrap_or(false);

    if !has_feed {
        let name = sqlx::query_scalar::<_, Option<String>>(
            "SELECT full_name FROM users WHERE id = $1"
        )
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await
        .ok()
        .flatten()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "Teacher".to_string());

        let feed_title = format!("{} Feed", name);
        if let Err(e) = sqlx::query(
            "INSERT INTO feeds (owner_type, owner_user_id, title) VALUES ('teacher', $1, $2)"
        )
        .bind(user_id)
        .bind(&feed_title)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to create teacher feed: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create teacher feed"
            }));
        }
    }

    // Commit transaction
    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "User converted to teacher successfully"
    }))
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    debug!("=== ADMIN CONFIGURE CALLED ===");
    cfg.service(test_route)
        .service(get_users)
        .service(create_user)
        .service(update_user)
        .service(delete_user)
        .service(make_student)
        .service(make_parent)
        .service(make_teacher)
        .service(generate_reset_link)
        .service(get_password_reset_requests)
        .service(resolve_password_reset_request);
}
