use actix_web::{get, post, put, delete, web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, Utc, NaiveDate};

use crate::AppState;
use crate::users::verify_token;

// ============================================================================
// Models
// ============================================================================

#[derive(Debug, Serialize, FromRow)]
pub struct Student {
    pub user_id: i32,
    pub full_name: String,
    pub address: String,
    pub birthday: NaiveDate,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow)]
pub struct Parent {
    pub user_id: i32,
    pub full_name: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow)]
pub struct Teacher {
    pub user_id: i32,
    pub full_name: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct StudentWithUserInfo {
    pub user_id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub address: String,
    pub birthday: NaiveDate,
}

#[derive(Debug, Serialize)]
pub struct ParentWithUserInfo {
    pub user_id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub children: Option<Vec<StudentWithUserInfo>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateStudentRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub address: String,
    pub birthday: String, // ISO 8601 format (YYYY-MM-DD)
}

#[derive(Debug, Deserialize)]
pub struct CreateParentRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub student_ids: Vec<i32>, // At least one required
}

#[derive(Debug, Deserialize)]
pub struct CreateTeacherRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateStudentRequest {
    pub full_name: Option<String>,
    pub address: Option<String>,
    pub birthday: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateParentRequest {
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTeacherRequest {
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AddParentStudentRelationRequest {
    pub student_id: i32,
}

// ============================================================================
// Helper functions
// ============================================================================

fn verify_admin_role(req: &HttpRequest, app_state: &AppState) -> Result<(), HttpResponse> {
    let claims = verify_token(req, app_state)?;
    
    if !claims.roles.contains(&"admin".to_string()) {
        return Err(HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Admin access required"
        })));
    }
    
    Ok(())
}

/// Check if user is allowed to modify a student profile
/// Returns Ok(()) if user is admin or parent of the student
async fn verify_can_edit_student(
    req: &HttpRequest,
    app_state: &AppState,
    student_user_id: i32,
) -> Result<(), HttpResponse> {
    let claims = verify_token(req, app_state)?;
    
    // Admins can edit anyone
    if claims.roles.contains(&"admin".to_string()) {
        return Ok(());
    }
    
    // Get the current user's ID
    let user_result = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await;
    
    let current_user_id = match user_result {
        Ok(Some(id)) => id,
        _ => return Err(HttpResponse::Unauthorized().json(serde_json::json!({
            "error": "User not found"
        }))),
    };
    
    // Check if current user is a parent of this student
    let relation_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM parent_student_relations 
            WHERE parent_user_id = $1 AND student_user_id = $2
        )"
    )
    .bind(current_user_id)
    .bind(student_user_id)
    .fetch_one(&app_state.db)
    .await;
    
    match relation_exists {
        Ok(true) => Ok(()),
        _ => Err(HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized to edit this student"
        }))),
    }
}

// ============================================================================
// Student Routes
// ============================================================================

#[post("/api/admin/students")]
async fn create_student(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    student_req: web::Json<CreateStudentRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    // Hash password
    use argon2::{Argon2, PasswordHasher};
    use argon2::password_hash::{SaltString, rand_core::OsRng};
    
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = match argon2.hash_password(student_req.password.as_bytes(), &salt) {
        Ok(hash) => hash.to_string(),
        Err(_) => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to hash password"
            }));
        }
    };
    
    // Parse birthday
    let birthday = match NaiveDate::parse_from_str(&student_req.birthday, "%Y-%m-%d") {
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
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Create user
    let user_id = match sqlx::query_scalar::<_, i32>(
        "INSERT INTO users (username, password_hash, email, phone) 
         VALUES ($1, $2, $3, $4) RETURNING id"
    )
    .bind(&student_req.username)
    .bind(&password_hash)
    .bind(&student_req.email)
    .bind(&student_req.phone)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to create user: {}", e);
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Username already exists or database error"
            }));
        }
    };
    
    // Get student role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = 'student'"
    )
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to get student role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Student role not found"
            }));
        }
    };
    
    // Assign student role
    if let Err(e) = sqlx::query(
        "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
    )
    .bind(user_id)
    .bind(role_id)
    .execute(&mut *tx)
    .await
    {
        eprintln!("Failed to assign role: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to assign role"
        }));
    }
    
    // Create student entry
    if let Err(e) = sqlx::query(
        "INSERT INTO students (user_id, full_name, address, birthday) 
         VALUES ($1, $2, $3, $4)"
    )
    .bind(user_id)
    .bind(&student_req.full_name)
    .bind(&student_req.address)
    .bind(birthday)
    .execute(&mut *tx)
    .await
    {
        eprintln!("Failed to create student entry: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create student"
        }));
    }
    
    // Commit transaction
    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }
    
    HttpResponse::Created().json(serde_json::json!({
        "id": user_id,
        "username": student_req.username
    }))
}

#[get("/api/students/{user_id}")]
async fn get_student(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let user_id = path.into_inner();
    
    // Verify authentication
    if let Err(response) = verify_token(&req, &app_state) {
        return response;
    }
    
    // Get student with user info
    let student = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String, NaiveDate)>(
        "SELECT u.id, u.username, u.email, u.phone, s.full_name, s.address, s.birthday
         FROM users u
         INNER JOIN students s ON u.id = s.user_id
         WHERE u.id = $1"
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await;
    
    match student {
        Ok(Some((user_id, username, email, phone, full_name, address, birthday))) => {
            HttpResponse::Ok().json(StudentWithUserInfo {
                user_id,
                username,
                email,
                phone,
                full_name,
                address,
                birthday,
            })
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "error": "Student not found"
        })),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

#[put("/api/students/{user_id}")]
async fn update_student(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    update_req: web::Json<UpdateStudentRequest>,
) -> impl Responder {
    let user_id = path.into_inner();
    
    // Verify user can edit this student
    if let Err(response) = verify_can_edit_student(&req, &app_state, user_id).await {
        return response;
    }
    
    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Update user table if email or phone changed
    if update_req.email.is_some() || update_req.phone.is_some() {
        let mut query = String::from("UPDATE users SET ");
        let mut updates = Vec::new();
        let mut bind_count = 1;
        
        if update_req.email.is_some() {
            updates.push(format!("email = ${}", bind_count));
            bind_count += 1;
        }
        
        if update_req.phone.is_some() {
            updates.push(format!("phone = ${}", bind_count));
            bind_count += 1;
        }
        
        query.push_str(&updates.join(", "));
        query.push_str(&format!(" WHERE id = ${}", bind_count));
        
        let mut q = sqlx::query(&query);
        
        if let Some(ref email) = update_req.email {
            q = q.bind(email);
        }
        
        if let Some(ref phone) = update_req.phone {
            q = q.bind(phone);
        }
        
        q = q.bind(user_id);
        
        if let Err(e) = q.execute(&mut *tx).await {
            eprintln!("Failed to update user: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update user info"
            }));
        }
    }
    
    // Update student table
    if update_req.full_name.is_some() || update_req.address.is_some() || update_req.birthday.is_some() {
        let mut query = String::from("UPDATE students SET ");
        let mut updates = Vec::new();
        let mut bind_count = 1;
        
        let birthday_date = if let Some(ref birthday_str) = update_req.birthday {
            match NaiveDate::parse_from_str(birthday_str, "%Y-%m-%d") {
                Ok(date) => Some(date),
                Err(_) => {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(serde_json::json!({
                        "error": "Invalid birthday format. Use YYYY-MM-DD"
                    }));
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
        
        query.push_str(&updates.join(", "));
        query.push_str(&format!(" WHERE user_id = ${}", bind_count));
        
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
            eprintln!("Failed to update student: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update student info"
            }));
        }
        
        // Sync full_name to other role tables if updated
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
    
    // Commit transaction
    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }
    
    HttpResponse::Ok().json(serde_json::json!({
        "message": "Student updated successfully"
    }))
}

// ============================================================================
// Parent Routes
// ============================================================================

#[post("/api/admin/parents")]
async fn create_parent(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    parent_req: web::Json<CreateParentRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    // Validate at least one student
    if parent_req.student_ids.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "At least one student is required"
        }));
    }
    
    // Hash password
    use argon2::{Argon2, PasswordHasher};
    use argon2::password_hash::{SaltString, rand_core::OsRng};
    
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = match argon2.hash_password(parent_req.password.as_bytes(), &salt) {
        Ok(hash) => hash.to_string(),
        Err(_) => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to hash password"
            }));
        }
    };
    
    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Create user
    let user_id = match sqlx::query_scalar::<_, i32>(
        "INSERT INTO users (username, password_hash, email, phone) 
         VALUES ($1, $2, $3, $4) RETURNING id"
    )
    .bind(&parent_req.username)
    .bind(&password_hash)
    .bind(&parent_req.email)
    .bind(&parent_req.phone)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to create user: {}", e);
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Username already exists or database error"
            }));
        }
    };
    
    // Get parent role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = 'parent'"
    )
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to get parent role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Parent role not found"
            }));
        }
    };
    
    // Assign parent role
    if let Err(e) = sqlx::query(
        "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
    )
    .bind(user_id)
    .bind(role_id)
    .execute(&mut *tx)
    .await
    {
        eprintln!("Failed to assign role: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to assign role"
        }));
    }
    
    // Create parent entry
    if let Err(e) = sqlx::query(
        "INSERT INTO parents (user_id, full_name) VALUES ($1, $2)"
    )
    .bind(user_id)
    .bind(&parent_req.full_name)
    .execute(&mut *tx)
    .await
    {
        eprintln!("Failed to create parent entry: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create parent"
        }));
    }
    
    // Create parent-student relations
    for student_id in &parent_req.student_ids {
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
             VALUES ($1, $2)"
        )
        .bind(user_id)
        .bind(student_id)
        .execute(&mut *tx)
        .await
        {
            eprintln!("Failed to create relation: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create parent-student relation"
            }));
        }
    }
    
    // Commit transaction
    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }
    
    HttpResponse::Created().json(serde_json::json!({
        "id": user_id,
        "username": parent_req.username
    }))
}

#[get("/api/parents/{user_id}")]
async fn get_parent(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let user_id = path.into_inner();
    
    // Verify authentication
    if let Err(response) = verify_token(&req, &app_state) {
        return response;
    }
    
    // Get parent with user info
    let parent = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String)>(
        "SELECT u.id, u.username, u.email, u.phone, p.full_name
         FROM users u
         INNER JOIN parents p ON u.id = p.user_id
         WHERE u.id = $1"
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await;
    
    match parent {
        Ok(Some((user_id, username, email, phone, full_name))) => {
            // Get children
            let children = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String, NaiveDate)>(
                "SELECT u.id, u.username, u.email, u.phone, s.full_name, s.address, s.birthday
                 FROM users u
                 INNER JOIN students s ON u.id = s.user_id
                 INNER JOIN parent_student_relations psr ON s.user_id = psr.student_user_id
                 WHERE psr.parent_user_id = $1"
            )
            .bind(user_id)
            .fetch_all(&app_state.db)
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|(user_id, username, email, phone, full_name, address, birthday)| {
                StudentWithUserInfo {
                    user_id,
                    username,
                    email,
                    phone,
                    full_name,
                    address,
                    birthday,
                }
            })
            .collect();
            
            HttpResponse::Ok().json(ParentWithUserInfo {
                user_id,
                username,
                email,
                phone,
                full_name,
                children: Some(children),
            })
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "error": "Parent not found"
        })),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

#[put("/api/parents/{user_id}")]
async fn update_parent(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    update_req: web::Json<UpdateParentRequest>,
) -> impl Responder {
    let user_id = path.into_inner();
    
    // Only admins or the parent themselves can update
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };
    
    let current_user_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(id)) => id,
        _ => {
            return HttpResponse::Unauthorized().json(serde_json::json!({
                "error": "User not found"
            }));
        }
    };
    
    if !claims.roles.contains(&"admin".to_string()) && current_user_id != user_id {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
        }));
    }
    
    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Update user table if email or phone changed
    if update_req.email.is_some() || update_req.phone.is_some() {
        let mut query = String::from("UPDATE users SET ");
        let mut updates = Vec::new();
        let mut bind_count = 1;
        
        if update_req.email.is_some() {
            updates.push(format!("email = ${}", bind_count));
            bind_count += 1;
        }
        
        if update_req.phone.is_some() {
            updates.push(format!("phone = ${}", bind_count));
            bind_count += 1;
        }
        
        query.push_str(&updates.join(", "));
        query.push_str(&format!(" WHERE id = ${}", bind_count));
        
        let mut q = sqlx::query(&query);
        
        if let Some(ref email) = update_req.email {
            q = q.bind(email);
        }
        
        if let Some(ref phone) = update_req.phone {
            q = q.bind(phone);
        }
        
        q = q.bind(user_id);
        
        if let Err(e) = q.execute(&mut *tx).await {
            eprintln!("Failed to update user: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update user info"
            }));
        }
    }
    
    // Update parent table
    if let Some(ref full_name) = update_req.full_name {
        if let Err(e) = sqlx::query(
            "UPDATE parents SET full_name = $1 WHERE user_id = $2"
        )
        .bind(full_name)
        .bind(user_id)
        .execute(&mut *tx)
        .await
        {
            eprintln!("Failed to update parent: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update parent info"
            }));
        }
        
        // Sync full_name to other role tables
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
    
    // Commit transaction
    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }
    
    HttpResponse::Ok().json(serde_json::json!({
        "message": "Parent updated successfully"
    }))
}

#[post("/api/parents/{user_id}/students")]
async fn add_parent_student_relation(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    relation_req: web::Json<AddParentStudentRelationRequest>,
) -> impl Responder {
    let parent_user_id = path.into_inner();
    
    // Only admins can add relations
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    // Prevent self-parenting
    if parent_user_id == relation_req.student_id {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "A user cannot be their own parent"
        }));
    }
    
    // Verify parent exists
    let parent_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM parents WHERE user_id = $1)"
    )
    .bind(parent_user_id)
    .fetch_one(&app_state.db)
    .await;
    
    if !parent_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Parent not found"
        }));
    }
    
    // Verify student exists
    let student_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1)"
    )
    .bind(relation_req.student_id)
    .fetch_one(&app_state.db)
    .await;
    
    if !student_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Student not found"
        }));
    }
    
    // Create relation
    match sqlx::query(
        "INSERT INTO parent_student_relations (parent_user_id, student_user_id) 
         VALUES ($1, $2)"
    )
    .bind(parent_user_id)
    .bind(relation_req.student_id)
    .execute(&app_state.db)
    .await
    {
        Ok(_) => HttpResponse::Created().json(serde_json::json!({
            "message": "Relation created successfully"
        })),
        Err(e) => {
            eprintln!("Failed to create relation: {}", e);
            HttpResponse::Conflict().json(serde_json::json!({
                "error": "Relation already exists or database error"
            }))
        }
    }
}

#[delete("/api/parents/{parent_id}/students/{student_id}")]
async fn remove_parent_student_relation(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
) -> impl Responder {
    let (parent_user_id, student_user_id) = path.into_inner();
    
    // Only admins can remove relations
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    match sqlx::query(
        "DELETE FROM parent_student_relations 
         WHERE parent_user_id = $1 AND student_user_id = $2"
    )
    .bind(parent_user_id)
    .bind(student_user_id)
    .execute(&app_state.db)
    .await
    {
        Ok(result) => {
            if result.rows_affected() > 0 {
                HttpResponse::Ok().json(serde_json::json!({
                    "message": "Relation removed successfully"
                }))
            } else {
                HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Relation not found"
                }))
            }
        }
        Err(e) => {
            eprintln!("Failed to remove relation: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

// ============================================================================
// Teacher Routes
// ============================================================================

#[post("/api/admin/teachers")]
async fn create_teacher(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    teacher_req: web::Json<CreateTeacherRequest>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    // Hash password
    use argon2::{Argon2, PasswordHasher};
    use argon2::password_hash::{SaltString, rand_core::OsRng};
    
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = match argon2.hash_password(teacher_req.password.as_bytes(), &salt) {
        Ok(hash) => hash.to_string(),
        Err(_) => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to hash password"
            }));
        }
    };
    
    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Create user
    let user_id = match sqlx::query_scalar::<_, i32>(
        "INSERT INTO users (username, password_hash, email, phone) 
         VALUES ($1, $2, $3, $4) RETURNING id"
    )
    .bind(&teacher_req.username)
    .bind(&password_hash)
    .bind(&teacher_req.email)
    .bind(&teacher_req.phone)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to create user: {}", e);
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Username already exists or database error"
            }));
        }
    };
    
    // Get teacher role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = 'teacher'"
    )
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to get teacher role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Teacher role not found"
            }));
        }
    };
    
    // Assign teacher role
    if let Err(e) = sqlx::query(
        "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)"
    )
    .bind(user_id)
    .bind(role_id)
    .execute(&mut *tx)
    .await
    {
        eprintln!("Failed to assign role: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to assign role"
        }));
    }
    
    // Create teacher entry
    if let Err(e) = sqlx::query(
        "INSERT INTO teachers (user_id, full_name) VALUES ($1, $2)"
    )
    .bind(user_id)
    .bind(&teacher_req.full_name)
    .execute(&mut *tx)
    .await
    {
        eprintln!("Failed to create teacher entry: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create teacher"
        }));
    }
    
    // Commit transaction
    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }
    
    HttpResponse::Created().json(serde_json::json!({
        "id": user_id,
        "username": teacher_req.username
    }))
}

#[get("/api/teachers/{user_id}")]
async fn get_teacher(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let user_id = path.into_inner();
    
    // Verify authentication
    if let Err(response) = verify_token(&req, &app_state) {
        return response;
    }
    
    // Get teacher with user info
    let teacher = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String)>(
        "SELECT u.id, u.username, u.email, u.phone, t.full_name
         FROM users u
         INNER JOIN teachers t ON u.id = t.user_id
         WHERE u.id = $1"
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await;
    
    match teacher {
        Ok(Some((user_id, username, email, phone, full_name))) => {
            HttpResponse::Ok().json(serde_json::json!({
                "user_id": user_id,
                "username": username,
                "email": email,
                "phone": phone,
                "full_name": full_name,
            }))
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "error": "Teacher not found"
        })),
        Err(e) => {
            eprintln!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

#[put("/api/teachers/{user_id}")]
async fn update_teacher(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    update_req: web::Json<UpdateTeacherRequest>,
) -> impl Responder {
    let user_id = path.into_inner();
    
    // Only admins or the teacher themselves can update
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };
    
    let current_user_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(id)) => id,
        _ => {
            return HttpResponse::Unauthorized().json(serde_json::json!({
                "error": "User not found"
            }));
        }
    };
    
    if !claims.roles.contains(&"admin".to_string()) && current_user_id != user_id {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
        }));
    }
    
    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Update user table if email or phone changed
    if update_req.email.is_some() || update_req.phone.is_some() {
        let mut query = String::from("UPDATE users SET ");
        let mut updates = Vec::new();
        let mut bind_count = 1;
        
        if update_req.email.is_some() {
            updates.push(format!("email = ${}", bind_count));
            bind_count += 1;
        }
        
        if update_req.phone.is_some() {
            updates.push(format!("phone = ${}", bind_count));
            bind_count += 1;
        }
        
        query.push_str(&updates.join(", "));
        query.push_str(&format!(" WHERE id = ${}", bind_count));
        
        let mut q = sqlx::query(&query);
        
        if let Some(ref email) = update_req.email {
            q = q.bind(email);
        }
        
        if let Some(ref phone) = update_req.phone {
            q = q.bind(phone);
        }
        
        q = q.bind(user_id);
        
        if let Err(e) = q.execute(&mut *tx).await {
            eprintln!("Failed to update user: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update user info"
            }));
        }
    }
    
    // Update teacher table
    if let Some(ref full_name) = update_req.full_name {
        if let Err(e) = sqlx::query(
            "UPDATE teachers SET full_name = $1 WHERE user_id = $2"
        )
        .bind(full_name)
        .bind(user_id)
        .execute(&mut *tx)
        .await
        {
            eprintln!("Failed to update teacher: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update teacher info"
            }));
        }
        
        // Sync full_name to other role tables
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
    
    // Commit transaction
    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }
    
    HttpResponse::Ok().json(serde_json::json!({
        "message": "Teacher updated successfully"
    }))
}

pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg
        // Student routes
        .service(create_student)
        .service(get_student)
        .service(update_student)
        // Parent routes
        .service(create_parent)
        .service(get_parent)
        .service(update_parent)
        .service(add_parent_student_relation)
        .service(remove_parent_student_relation)
        // Teacher routes
        .service(create_teacher)
        .service(get_teacher)
        .service(update_teacher);
}
