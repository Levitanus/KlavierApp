use actix_web::{delete, get, post, put, web, HttpRequest, HttpResponse, Responder};
use chrono::NaiveDate;
use log::{error};

use super::helpers::verify_admin_role;
use super::models::{
    AddTeacherStudentRelationRequest, CreateTeacherRequest, StudentWithUserInfo,
     UpdateTeacherRequest,
};
use crate::users::verify_token;
use crate::AppState;

// ============================================================================
// Teacher Routes
// ============================================================================

#[post("/api/admin/teachers")]
pub(crate) async fn create_teacher(
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
    .bind(&teacher_req.username)
    .bind(&teacher_req.full_name)
    .bind(&password_hash)
    .bind(&teacher_req.email)
    .bind(&teacher_req.phone)
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

    // Assign teacher role
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

    let feed_title = format!("{} Feed", teacher_req.full_name);
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

    // Commit transaction
    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
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
pub(crate) async fn get_teacher(
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
    let teacher = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, t.status::text
         FROM users u
         INNER JOIN teachers t ON u.id = t.user_id
         WHERE u.id = $1"
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await;

    match teacher {
        Ok(Some((user_id, username, email, phone, full_name, status))) => {
            HttpResponse::Ok().json(serde_json::json!({
                "user_id": user_id,
                "username": username,
                "email": email,
                "phone": phone,
                "full_name": full_name,
                "status": status,
            }))
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "error": "Teacher not found"
        })),
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

#[put("/api/teachers/{user_id}")]
pub(crate) async fn update_teacher(
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
        "message": "Teacher updated successfully"
    }))
}

// ============================================================================
// Teacher-Student Relation Routes
// ============================================================================

#[get("/api/teachers/{teacher_id}/students")]
pub(crate) async fn list_teacher_students(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let teacher_id = path.into_inner();

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

    if !claims.roles.contains(&"admin".to_string()) && current_user_id != teacher_id {
        let is_related_student = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1 FROM teacher_student_relations
                WHERE teacher_user_id = $1 AND student_user_id = $2
            )"
        )
        .bind(teacher_id)
        .bind(current_user_id)
        .fetch_one(&app_state.db)
        .await
        .unwrap_or(false);

        let is_related_parent = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1 FROM parent_student_relations psr
                JOIN teacher_student_relations tsr ON psr.student_user_id = tsr.student_user_id
                WHERE psr.parent_user_id = $1 AND tsr.teacher_user_id = $2
            )"
        )
        .bind(current_user_id)
        .bind(teacher_id)
        .fetch_one(&app_state.db)
        .await
        .unwrap_or(false);

        if !is_related_student && !is_related_parent {
            return HttpResponse::Forbidden().json(serde_json::json!({
                "error": "Not authorized"
            }));
        }
    }

    let students: Vec<StudentWithUserInfo> = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String, NaiveDate, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, s.address, s.birthday, s.status::text
         FROM users u
         INNER JOIN students s ON u.id = s.user_id
         INNER JOIN teacher_student_relations tsr ON s.user_id = tsr.student_user_id
         WHERE tsr.teacher_user_id = $1"
    )
    .bind(teacher_id)
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

    HttpResponse::Ok().json(students)
}

#[post("/api/teachers/{teacher_id}/students")]
pub(crate) async fn add_teacher_student_relation(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    relation_req: web::Json<AddTeacherStudentRelationRequest>,
) -> impl Responder {
    let teacher_id = path.into_inner();

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

    if !claims.roles.contains(&"admin".to_string()) && current_user_id != teacher_id {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
        }));
    }

    if teacher_id == relation_req.student_id {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "A user cannot be their own teacher"
        }));
    }

    let teacher_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM teachers WHERE user_id = $1)"
    )
    .bind(teacher_id)
    .fetch_one(&app_state.db)
    .await;

    if !teacher_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Teacher not found"
        }));
    }

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

    match sqlx::query(
        "INSERT INTO teacher_student_relations (teacher_user_id, student_user_id)
         VALUES ($1, $2)"
    )
    .bind(teacher_id)
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

#[delete("/api/teachers/{teacher_id}/students/{student_id}")]
pub(crate) async fn remove_teacher_student_relation(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
) -> impl Responder {
    let (teacher_id, student_id) = path.into_inner();

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

    if !claims.roles.contains(&"admin".to_string()) && current_user_id != teacher_id {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
        }));
    }

    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    let delete_result = match sqlx::query(
        "DELETE FROM teacher_student_relations
         WHERE teacher_user_id = $1 AND student_user_id = $2"
    )
    .bind(teacher_id)
    .bind(student_id)
    .execute(&mut *tx)
    .await
    {
        Ok(result) => result,
        Err(e) => {
            error!("Failed to remove relation: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    if delete_result.rows_affected() == 0 {
        let _ = tx.rollback().await;
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Relation not found"
        }));
    }

    if let Err(e) = sqlx::query(
        "UPDATE hometasks
         SET status = 'accomplished_by_teacher', updated_at = NOW()
         WHERE teacher_id = $1 AND student_id = $2
           AND status <> 'accomplished_by_teacher'"
    )
    .bind(teacher_id)
    .bind(student_id)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to archive hometasks: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to archive hometasks"
        }));
    }

    if let Err(e) = tx.commit().await {
        error!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Database error"
        }));
    }

    HttpResponse::Ok().json(serde_json::json!({
        "message": "Relation removed successfully"
    }))
}

// ============================================================================
// Teacher Role Archive/Unarchive Endpoints
// ============================================================================

#[post("/api/admin/teachers/{user_id}/archive")]
pub(crate) async fn archive_teacher_role(
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

    // Archive the teacher role
    let result = sqlx::query(
        "UPDATE teachers SET status = 'archived', archived_at = NOW(), archived_by = $1 WHERE user_id = $2"
    )
    .bind(admin_user_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await;

    match result {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Teacher role not found"
                }));
            }
            HttpResponse::Ok().json(serde_json::json!({
                "message": "Teacher role archived successfully"
            }))
        }
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to archive teacher role"
            }))
        }
    }
}

#[post("/api/admin/teachers/{user_id}/unarchive")]
pub(crate) async fn unarchive_teacher_role(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    // Unarchive the teacher role
    let result = sqlx::query(
        "UPDATE teachers SET status = 'active', archived_at = NULL, archived_by = NULL WHERE user_id = $1"
    )
    .bind(user_id)
    .execute(&app_state.db)
    .await;

    match result {
        Ok(result) => {
            if result.rows_affected() == 0 {
                return HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Teacher role not found"
                }));
            }
            HttpResponse::Ok().json(serde_json::json!({
                "message": "Teacher role unarchived successfully"
            }))
        }
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to unarchive teacher role"
            }))
        }
    }
}
