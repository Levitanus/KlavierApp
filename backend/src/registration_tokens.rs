use actix_web::{get, post, web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, Utc, Duration, NaiveDate};
use sha2::{Sha256, Digest};
use uuid::Uuid;
use argon2::{Argon2, PasswordHasher};
use argon2::password_hash::{SaltString, rand_core::OsRng};
use log::{error};

use crate::AppState;
use crate::users::verify_token;

#[derive(Debug, Serialize, FromRow)]
pub struct RegistrationToken {
    pub id: i32,
    pub token_hash: String,
    pub created_by_user_id: i32,
    pub role: String,
    pub related_student_id: Option<i32>,
    pub related_teacher_id: Option<i32>,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub used_at: Option<DateTime<Utc>>,
    pub used_by_user_id: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct CreateRegistrationTokenRequest {
    pub role: String, // 'student', 'parent', or 'teacher'
    pub related_student_id: Option<i32>, // Required for parent tokens from student profile
    pub related_teacher_id: Option<i32>, // Optional for student tokens tied to a teacher
}

#[derive(Debug, Serialize)]
pub struct CreateRegistrationTokenResponse {
    pub token: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct RegisterWithTokenRequest {
    pub token: String,
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    // Student-specific fields
    pub birthday: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TokenInfoResponse {
    pub valid: bool,
    pub role: Option<String>,
    pub related_student: Option<StudentInfo>,
    pub related_teacher: Option<TeacherInfo>,
}

#[derive(Debug, Serialize)]
pub struct StudentInfo {
    pub user_id: i32,
    pub username: String,
    pub full_name: String,
}

#[derive(Debug, Serialize)]
pub struct TeacherInfo {
    pub user_id: i32,
    pub username: String,
    pub full_name: String,
}

fn verify_admin_role(req: &HttpRequest, app_state: &AppState) -> Result<(), HttpResponse> {
    let claims = verify_token(req, app_state)?;
    
    if !claims.roles.contains(&"admin".to_string()) {
        return Err(HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Admin access required"
        })));
    }
    
    Ok(())
}

/// Admin creates a registration token
#[post("/api/admin/registration-tokens")]
async fn create_registration_token(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    token_req: web::Json<CreateRegistrationTokenRequest>,
) -> impl Responder {
    // Verify admin role
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    // Validate role
    if !["student", "parent", "teacher"].contains(&token_req.role.as_str()) {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "Invalid role. Must be student, parent, or teacher"
        }));
    }
    
    // Get admin user ID
    let claims = verify_token(&req, &app_state).unwrap();
    let admin_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(id)) => id,
        _ => {
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Admin user not found"
            }));
        }
    };
    
    // Verify related student if provided
    if let Some(student_id) = token_req.related_student_id {
        let student_exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1)"
        )
        .bind(student_id)
        .fetch_one(&app_state.db)
        .await;
        
        if !student_exists.unwrap_or(false) {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Related student not found"
            }));
        }
    }

    if let Some(teacher_id) = token_req.related_teacher_id {
        let teacher_exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM teachers WHERE user_id = $1)"
        )
        .bind(teacher_id)
        .fetch_one(&app_state.db)
        .await;

        if !teacher_exists.unwrap_or(false) {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Related teacher not found"
            }));
        }
    }
    
    // Generate token
    let token = Uuid::new_v4().to_string();
    
    // Hash token
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());
    
    // Token expires in 48 hours
    let expires_at = Utc::now() + Duration::hours(48);
    
    // Store token
    match sqlx::query(
           "INSERT INTO registration_tokens (token_hash, created_by_user_id, role, related_student_id, related_teacher_id, expires_at)
            VALUES ($1, $2, $3, $4, $5, $6)"
    )
    .bind(&token_hash)
    .bind(admin_id)
    .bind(&token_req.role)
    .bind(token_req.related_student_id)
        .bind(token_req.related_teacher_id)
    .bind(expires_at)
    .execute(&app_state.db)
    .await
    {
        Ok(_) => {
            HttpResponse::Created().json(CreateRegistrationTokenResponse {
                token,
                expires_at,
            })
        }
        Err(e) => {
            error!("Failed to create registration token: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create registration token"
            }))
        }
    }
}

/// Student creates a parent registration token
#[post("/api/students/{student_id}/parent-registration-token")]
async fn create_parent_token_from_student(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let student_id = path.into_inner();
    
    // Verify authentication
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };
    
    // Get current user ID
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
    
    // Verify user is the student or an admin
    if current_user_id != student_id && !claims.roles.contains(&"admin".to_string()) {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
        }));
    }
    
    // Verify student exists
    let student_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM students WHERE user_id = $1)"
    )
    .bind(student_id)
    .fetch_one(&app_state.db)
    .await;
    
    if !student_exists.unwrap_or(false) {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Student not found"
        }));
    }
    
    // Generate token
    let token = Uuid::new_v4().to_string();
    
    // Hash token
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());
    
    // Token expires in 48 hours
    let expires_at = Utc::now() + Duration::hours(48);
    
    // Store token
    match sqlx::query(
           "INSERT INTO registration_tokens (token_hash, created_by_user_id, role, related_student_id, related_teacher_id, expires_at)
            VALUES ($1, $2, 'parent', $3, NULL, $4)"
    )
    .bind(&token_hash)
    .bind(current_user_id)
    .bind(student_id)
    .bind(expires_at)
    .execute(&app_state.db)
    .await
    {
        Ok(_) => {
            HttpResponse::Created().json(CreateRegistrationTokenResponse {
                token,
                expires_at,
            })
        }
        Err(e) => {
            error!("Failed to create parent registration token: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create registration token"
            }))
        }
    }
}

/// Teacher creates a student registration token
#[post("/api/teachers/{teacher_id}/student-registration-token")]
async fn create_student_token_from_teacher(
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

    if current_user_id != teacher_id && !claims.roles.contains(&"admin".to_string()) {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Not authorized"
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

    let token = Uuid::new_v4().to_string();
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());
    let expires_at = Utc::now() + Duration::hours(48);

    match sqlx::query(
        "INSERT INTO registration_tokens (token_hash, created_by_user_id, role, related_student_id, related_teacher_id, expires_at)
         VALUES ($1, $2, 'student', NULL, $3, $4)"
    )
    .bind(&token_hash)
    .bind(current_user_id)
    .bind(teacher_id)
    .bind(expires_at)
    .execute(&app_state.db)
    .await
    {
        Ok(_) => HttpResponse::Created().json(CreateRegistrationTokenResponse {
            token,
            expires_at,
        }),
        Err(e) => {
            error!("Failed to create student registration token: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create registration token"
            }))
        }
    }
}

/// Validate and get info about a registration token
#[get("/api/registration-token-info/{token}")]
async fn get_token_info(
    app_state: web::Data<AppState>,
    token: web::Path<String>,
) -> impl Responder {
    // Hash provided token
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());
    
    // Fetch and validate token
    let token_record = match sqlx::query_as::<_, RegistrationToken>(
        "SELECT * FROM registration_tokens WHERE token_hash = $1"
    )
    .bind(&token_hash)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(token)) => token,
        Ok(None) => {
            return HttpResponse::Ok().json(TokenInfoResponse {
                valid: false,
                role: None,
                related_student: None,
                related_teacher: None,
            });
        }
        Err(e) => {
            error!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Check if token is already used
    if token_record.used_at.is_some() {
        return HttpResponse::Ok().json(TokenInfoResponse {
            valid: false,
            role: None,
            related_student: None,
            related_teacher: None,
        });
    }
    
    // Check if token is expired
    if token_record.expires_at < Utc::now() {
        return HttpResponse::Ok().json(TokenInfoResponse {
            valid: false,
            role: None,
            related_student: None,
            related_teacher: None,
        });
    }
    
    // Get related student info if exists
    let related_student = if let Some(student_id) = token_record.related_student_id {
        match sqlx::query_as::<_, (i32, String, String)>(
            "SELECT u.id, u.username, u.full_name 
             FROM users u 
             INNER JOIN students s ON u.id = s.user_id 
             WHERE u.id = $1"
        )
        .bind(student_id)
        .fetch_optional(&app_state.db)
        .await
        {
            Ok(Some((user_id, username, full_name))) => Some(StudentInfo {
                user_id,
                username,
                full_name,
            }),
            _ => None,
        }
    } else {
        None
    };

    let related_teacher = if let Some(teacher_id) = token_record.related_teacher_id {
        match sqlx::query_as::<_, (i32, String, String)>(
            "SELECT u.id, u.username, u.full_name
             FROM users u
             INNER JOIN teachers t ON u.id = t.user_id
             WHERE u.id = $1"
        )
        .bind(teacher_id)
        .fetch_optional(&app_state.db)
        .await
        {
            Ok(Some((user_id, username, full_name))) => Some(TeacherInfo {
                user_id,
                username,
                full_name,
            }),
            _ => None,
        }
    } else {
        None
    };
    
    HttpResponse::Ok().json(TokenInfoResponse {
        valid: true,
        role: Some(token_record.role),
        related_student,
        related_teacher,
    })
}

/// Register a new user with a token
#[post("/api/register-with-token")]
async fn register_with_token(
    app_state: web::Data<AppState>,
    register_req: web::Json<RegisterWithTokenRequest>,
) -> impl Responder {
    // Hash provided token
    let mut hasher = Sha256::new();
    hasher.update(register_req.token.as_bytes());
    let token_hash = format!("{:x}", hasher.finalize());
    
    // Fetch and validate token
    let token = match sqlx::query_as::<_, RegistrationToken>(
        "SELECT * FROM registration_tokens WHERE token_hash = $1"
    )
    .bind(&token_hash)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(token)) => token,
        Ok(None) => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Invalid token"
            }));
        }
        Err(e) => {
            error!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };
    
    // Check if token is already used
    if token.used_at.is_some() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "Token already used"
        }));
    }
    
    // Check if token is expired
    if token.expires_at < Utc::now() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "Token expired"
        }));
    }
    
    // Validate required fields based on role
    if token.role == "student" {
        if register_req.birthday.is_none() {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Birthday is required for student registration"
            }));
        }
    }
    
    // Hash password
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = match argon2.hash_password(register_req.password.as_bytes(), &salt) {
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
    .bind(&register_req.username)
    .bind(&register_req.full_name)
    .bind(&password_hash)
    .bind(&register_req.email)
    .bind(&register_req.phone)
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
    
    // Get role ID
    let role_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM roles WHERE name = $1"
    )
    .bind(&token.role)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to get role: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Role not found"
            }));
        }
    };
    
    // Assign role
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
    
    // Create role-specific entry
    match token.role.as_str() {
        "student" => {
            let birthday = match NaiveDate::parse_from_str(
                register_req.birthday.as_ref().unwrap(),
                "%Y-%m-%d"
            ) {
                Ok(date) => date,
                Err(_) => {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(serde_json::json!({
                        "error": "Invalid birthday format. Use YYYY-MM-DD"
                    }));
                }
            };
            
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

            if let Some(teacher_id) = token.related_teacher_id {
                if user_id == teacher_id {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(serde_json::json!({
                        "error": "A user cannot be their own teacher"
                    }));
                }

                if let Err(e) = sqlx::query(
                    "INSERT INTO teacher_student_relations (teacher_user_id, student_user_id)
                     VALUES ($1, $2)"
                )
                .bind(teacher_id)
                .bind(user_id)
                .execute(&mut *tx)
                .await
                {
                    error!("Failed to create teacher-student relation: {}", e);
                    let _ = tx.rollback().await;
                    return HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": "Failed to create teacher-student relation"
                    }));
                }
            }
        }
        "parent" => {
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
            
            // If related to a student, create relation
            if let Some(student_id) = token.related_student_id {
                // Prevent self-parenting
                if user_id == student_id {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(serde_json::json!({
                        "error": "A user cannot be their own parent"
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
                    error!("Failed to create parent-student relation: {}", e);
                    let _ = tx.rollback().await;
                    return HttpResponse::InternalServerError().json(serde_json::json!({
                        "error": "Failed to create parent-student relation"
                    }));
                }
            }
        }
        "teacher" => {
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
        }
        _ => {
            let _ = tx.rollback().await;
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Invalid role"
            }));
        }
    }
    
    // Mark token as used
    if let Err(e) = sqlx::query(
        "UPDATE registration_tokens SET used_at = NOW(), used_by_user_id = $1 
         WHERE token_hash = $2"
    )
    .bind(user_id)
    .bind(&token_hash)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to mark token as used: {}", e);
        // Don't rollback, just log the error
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
        "username": register_req.username,
        "role": token.role
    }))
}

/// Get list of registration tokens (admin only)
#[get("/api/admin/registration-tokens")]
async fn list_registration_tokens(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> impl Responder {
    // Verify admin role
    if let Err(response) = verify_admin_role(&req, &app_state) {
        return response;
    }
    
    match sqlx::query_as::<_, RegistrationToken>(
        "SELECT * FROM registration_tokens ORDER BY created_at DESC"
    )
    .fetch_all(&app_state.db)
    .await
    {
        Ok(tokens) => HttpResponse::Ok().json(tokens),
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        }
    }
}

pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg
        .service(create_registration_token)
        .service(create_parent_token_from_student)
    .service(create_student_token_from_teacher)
        .service(get_token_info)
        .service(register_with_token)
        .service(list_registration_tokens);
}
