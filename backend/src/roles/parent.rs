use actix_web::{delete, get, post, put, web, HttpRequest, HttpResponse, Responder};
use chrono::NaiveDate;
use log::{error};

use super::helpers::verify_admin_role;
use super::models::{
    AddParentStudentRelationRequest, CreateParentRequest, ParentWithUserInfo,
    StudentWithUserInfo, UpdateParentRequest,
};
use crate::users::verify_token;
use crate::AppState;

// ============================================================================
// Parent Routes
// ============================================================================

#[post("/api/admin/parents")]
pub(crate) async fn create_parent(
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
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    // Create user
    let user_id = match sqlx::query_scalar::<_, i32>(
        "INSERT INTO users (username, full_name, password_hash, email, phone) 
         VALUES ($1, $2, $3, $4, $5) RETURNING id"
    )
    .bind(&parent_req.username)
    .bind(&parent_req.full_name)
    .bind(&password_hash)
    .bind(&parent_req.email)
    .bind(&parent_req.phone)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to create user: {}", e);
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
            error!("Failed to get parent role: {}", e);
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
        error!("Failed to assign role: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to assign role"
        }));
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

    HttpResponse::Created().json(serde_json::json!({
        "id": user_id,
        "username": parent_req.username
    }))
}

#[get("/api/parents/{user_id}")]
pub(crate) async fn get_parent(
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
    let parent = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, p.status::text
         FROM users u
         INNER JOIN parents p ON u.id = p.user_id
         WHERE u.id = $1"
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await;

    match parent {
        Ok(Some((user_id, username, email, phone, full_name, status))) => {
            // Get children
            let children = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String, NaiveDate, String)>(
                "SELECT u.id, u.username, u.email, u.phone, u.full_name, s.address, s.birthday, s.status::text
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
            .map(|(user_id, username, email, phone, full_name, address, birthday, status)| {
                StudentWithUserInfo {
                    user_id,
                    username,
                    email,
                    phone,
                    full_name,
                    address,
                    birthday,
                    status,
                }
            })
            .collect();

            HttpResponse::Ok().json(ParentWithUserInfo {
                user_id,
                username,
                email,
                phone,
                full_name,
                status,
                children: Some(children),
            })
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "error": "Parent not found"
        })),
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

#[put("/api/parents/{user_id}")]
pub(crate) async fn update_parent(
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
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    // Update user table if email or phone changed
    if update_req.email.is_some() || update_req.phone.is_some() || update_req.full_name.is_some() {
        let mut query = String::from("UPDATE users SET ");
        let mut updates = Vec::new();
        let mut bind_count = 1;

        if update_req.full_name.is_some() {
            updates.push(format!("full_name = ${}", bind_count));
            bind_count += 1;
        }

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

        if let Some(ref full_name) = update_req.full_name {
            q = q.bind(full_name);
        }

        if let Some(ref email) = update_req.email {
            q = q.bind(email);
        }

        if let Some(ref phone) = update_req.phone {
            q = q.bind(phone);
        }

        q = q.bind(user_id);

        if let Err(e) = q.execute(&mut *tx).await {
            error!("Failed to update user: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update user info"
            }));
        }
    }

    // No role-table full_name updates needed

    // Commit transaction
    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to commit transaction"
        }));
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "Parent updated successfully"
    }))
}

#[post("/api/parents/{user_id}/students")]
pub(crate) async fn add_parent_student_relation(
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
            error!("Failed to create relation: {}", e);
            HttpResponse::Conflict().json(serde_json::json!({
                "error": "Relation already exists or database error"
            }))
        }
    }
}

#[delete("/api/parents/{parent_id}/students/{student_id}")]
pub(crate) async fn remove_parent_student_relation(
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
            error!("Failed to remove relation: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

// ============================================================================
// Parent Role Archive/Unarchive Endpoints
// ============================================================================

#[post("/api/admin/parents/{user_id}/archive")]
pub(crate) async fn archive_parent_role(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let user_id = user_id.into_inner();

    // Get the admin user ID from username
    let admin_user_id: Option<(i32,)> = sqlx::query_as(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    .unwrap_or(None);

    let admin_user_id = match admin_user_id {
        Some((id,)) => id,
        None => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Admin user not found"
            }));
        }
    };

    // Archive the parent role
    let result = sqlx::query(
        "UPDATE parents SET status = 'archived', archived_at = NOW(), archived_by = $1 WHERE user_id = $2"
    )
    .bind(admin_user_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await;

    match result {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Parent role not found"
                }));
            }
            HttpResponse::Ok().json(serde_json::json!({
                "message": "Parent role archived successfully"
            }))
        }
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to archive parent role"
            }))
        }
    }
}

#[post("/api/admin/parents/{user_id}/unarchive")]
pub(crate) async fn unarchive_parent_role(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Unarchive the parent role
    let result = sqlx::query(
        "UPDATE parents SET status = 'active', archived_at = NULL, archived_by = NULL WHERE user_id = $1"
    )
    .bind(user_id)
    .execute(&app_state.db)
    .await;

    match result {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Parent role not found"
                }));
            }
            HttpResponse::Ok().json(serde_json::json!({
                "message": "Parent role unarchived successfully"
            }))
        }
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to unarchive parent role"
            }))
        }
    }
}
