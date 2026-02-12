use actix_web::{delete, get, post, put, web, HttpRequest, HttpResponse, Responder};
use chrono::NaiveDate;
use log::{error};

use super::helpers::{
    check_and_archive_parents, check_and_unarchive_parents, verify_admin_role,
    verify_can_access_student, verify_can_edit_student,
};
use super::models::{ParentSummary, StudentWithUserInfo, TeacherWithUserInfo, CreateStudentRequest, UpdateStudentRequest};
use crate::users::verify_token;
use crate::AppState;

// ============================================================================
// Role Archive/Unarchive Endpoints
// ============================================================================

#[post("/api/admin/students/{user_id}/archive")]
pub(crate) async fn archive_student_role(
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

    // Start transaction
    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to start transaction"
            }));
        }
    };

    // Get the admin user ID from username
    let admin_user_id: Option<(i32,)> = match sqlx::query_as(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&mut *tx)
    .await {
        Ok(result) => result,
        Err(e) => {
            error!("Failed to get admin user ID: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to get admin user information"
            }));
        }
    };

    let admin_user_id = match admin_user_id {
        Some((id,)) => id,
        None => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Admin user not found"
            }));
        }
    };

    // Archive the student role
    let result = sqlx::query(
        "UPDATE students SET status = 'archived', archived_at = NOW(), archived_by = $1 WHERE user_id = $2"
    )
    .bind(admin_user_id)
    .bind(user_id)
    .execute(&mut *tx)
    .await;

    match result {
        Ok(result) => {
            if result.rows_affected() == 0 {
                let _ = tx.rollback().await;
                return HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Student role not found"
                }));
            }
            // Cascade to parents
            if let Err(e) = check_and_archive_parents(user_id, admin_user_id, &mut tx).await {
                error!("Failed to archive parents: {}", e);
                let _ = tx.rollback().await;
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to update parent status"
                }));
            }

            match tx.commit().await {
                Ok(_) => HttpResponse::Ok().json(serde_json::json!({
                    "message": "Student role archived successfully"
                })),
                Err(e) => {
                    error!("Failed to commit transaction: {}", e);
                    HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": "Failed to archive student role"
                    }))
                }
            }
        }
        Err(e) => {
            let _ = tx.rollback().await;
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to archive student role"
            }))
        }
    }
}

#[post("/api/admin/students/{user_id}/unarchive")]
pub(crate) async fn unarchive_student_role(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    user_id: web::Path<i32>,
) -> impl Responder {
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }

    let user_id = user_id.into_inner();

    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to start transaction"
            }));
        }
    };

    // Unarchive the student role
    let result = sqlx::query(
        "UPDATE students SET status = 'active', archived_at = NULL, archived_by = NULL WHERE user_id = $1"
    )
    .bind(user_id)
    .execute(&mut *tx)
    .await;

    match result {
        Ok(result) => {
            if result.rows_affected() == 0 {
                let _ = tx.rollback().await;
                return HttpResponse::NotFound().json(serde_json::json!({
                    "error": "Student role not found"
                }));
            }
            // Cascade to parents
            if let Err(e) = check_and_unarchive_parents(user_id, &mut tx).await {
                error!("Failed to unarchive parents: {}", e);
                let _ = tx.rollback().await;
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to update parent status"
                }));
            }

            match tx.commit().await {
                Ok(_) => HttpResponse::Ok().json(serde_json::json!({
                    "message": "Student role unarchived successfully"
                })),
                Err(e) => {
                    error!("Failed to commit transaction: {}", e);
                    HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": "Failed to unarchive student role"
                    }))
                }
            }
        }
        Err(e) => {
            let _ = tx.rollback().await;
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to unarchive student role"
            }))
        }
    }
}

// ============================================================================
// Student Routes
// ============================================================================

#[post("/api/admin/students")]
pub(crate) async fn create_student(
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
    .bind(&student_req.username)
        .bind(&student_req.full_name)
    .bind(&password_hash)
    .bind(&student_req.email)
    .bind(&student_req.phone)
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

    // Assign student role
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

    // Create student entry
    if let Err(e) = sqlx::query(
        "INSERT INTO students (user_id, address, birthday) 
           VALUES ($1, $2, $3)"
    )
    .bind(user_id)
    .bind(&student_req.address)
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

    HttpResponse::Created().json(serde_json::json!({
        "id": user_id,
        "username": student_req.username
    }))
}

#[get("/api/students/{user_id}")]
pub(crate) async fn get_student(
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
    let student = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String, NaiveDate, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, s.address, s.birthday, s.status::text
        FROM users u
        INNER JOIN students s ON u.id = s.user_id
        WHERE u.id = $1"
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await;

    match student {
        Ok(Some((user_id, username, email, phone, full_name, address, birthday, status))) => {
            HttpResponse::Ok().json(StudentWithUserInfo {
                user_id,
                username,
                email,
                phone,
                full_name,
                address,
                birthday,
                status,
            })
        }
        Ok(None) => HttpResponse::NotFound().json(serde_json::json!({
            "error": "Student not found"
        })),
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

#[get("/api/students")]
pub(crate) async fn list_students(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    if !claims.roles.contains(&"admin".to_string())
        && !claims.roles.contains(&"teacher".to_string())
    {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
        }));
    }

    let students: Vec<StudentWithUserInfo> = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String, NaiveDate, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, s.address, s.birthday, s.status::text
           FROM users u
           INNER JOIN students s ON u.id = s.user_id"
    )
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

#[put("/api/students/{user_id}")]
pub(crate) async fn update_student(
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

    // Update student table
    if update_req.address.is_some() || update_req.birthday.is_some() {
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

        if let Some(ref address) = update_req.address {
            q = q.bind(address);
        }

        if let Some(date) = birthday_date {
            q = q.bind(date);
        }

        q = q.bind(user_id);

        if let Err(e) = q.execute(&mut *tx).await {
            error!("Failed to update student: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update student info"
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
        "message": "Student updated successfully"
    }))
}

#[get("/api/students/{student_id}/teachers")]
pub(crate) async fn list_student_teachers(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let student_id = path.into_inner();

    if let Err(response) = verify_can_access_student(&req, &app_state, student_id).await {
        return response;
    }

    let teachers: Vec<TeacherWithUserInfo> = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, t.status::text
         FROM users u
         INNER JOIN teachers t ON u.id = t.user_id
         INNER JOIN teacher_student_relations tsr ON t.user_id = tsr.teacher_user_id
         WHERE tsr.student_user_id = $1"
    )
    .bind(student_id)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default()
    .into_iter()
    .map(|(user_id, username, email, phone, full_name, status)| {
        TeacherWithUserInfo {
            user_id,
            username,
            email,
            phone,
            full_name,
            status,
        }
    })
    .collect();

    HttpResponse::Ok().json(teachers)
}

#[delete("/api/students/{student_id}/teachers/{teacher_id}")]
pub(crate) async fn remove_student_teacher_relation(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
) -> impl Responder {
    let (student_id, teacher_id) = path.into_inner();

    if let Err(response) = verify_can_access_student(&req, &app_state, student_id).await {
        return response;
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

#[get("/api/students/{student_id}/parents")]
pub(crate) async fn list_student_parents(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let student_id = path.into_inner();

    if let Err(response) = verify_can_access_student(&req, &app_state, student_id).await {
        return response;
    }

    let parents: Vec<ParentSummary> = sqlx::query_as::<_, (i32, String, Option<String>, Option<String>, String, String)>(
        "SELECT u.id, u.username, u.email, u.phone, u.full_name, p.status::text
         FROM users u
         INNER JOIN parents p ON u.id = p.user_id
         INNER JOIN parent_student_relations psr ON p.user_id = psr.parent_user_id
         WHERE psr.student_user_id = $1"
    )
    .bind(student_id)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default()
    .into_iter()
    .map(|(user_id, username, email, phone, full_name, status)| ParentSummary {
        user_id,
        username,
        email,
        phone,
        full_name,
        status,
    })
    .collect();

    HttpResponse::Ok().json(parents)
}
