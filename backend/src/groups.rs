use actix_web::{delete, get, post, put, web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use log::error;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

use crate::users::{verify_token, Claims};
use crate::AppState;

#[derive(Debug, Serialize, FromRow)]
struct GroupRecord {
    id: i32,
    teacher_user_id: i32,
    name: String,
    status: String,
    archived_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow)]
struct GroupStudent {
    user_id: i32,
    username: String,
    full_name: String,
    email: Option<String>,
    phone: Option<String>,
}

#[derive(Debug, Serialize)]
struct GroupResponse {
    id: i32,
    teacher_user_id: i32,
    name: String,
    status: String,
    archived_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    students: Vec<GroupStudent>,
}

#[derive(Debug, Deserialize)]
struct ListGroupsQuery {
    include_archived: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct CreateGroupRequest {
    name: String,
    student_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
struct UpdateGroupRequest {
    name: Option<String>,
    student_ids: Option<Vec<i32>>,
    archived: Option<bool>,
}

async fn get_current_user_id(claims: &Claims, app_state: &AppState) -> Result<i32, HttpResponse> {
    sqlx::query_scalar::<_, i32>("SELECT id FROM users WHERE username = $1")
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await
        .map_err(|e| {
            error!("Failed to resolve current user id: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }))
        })?
        .ok_or_else(|| {
            HttpResponse::Unauthorized().json(serde_json::json!({
                "error": "User not found"
            }))
        })
}

async fn ensure_manage_access(
    claims: &Claims,
    current_user_id: i32,
    teacher_id: i32,
) -> Result<(), HttpResponse> {
    if claims.roles.contains(&"admin".to_string()) || current_user_id == teacher_id {
        return Ok(());
    }

    Err(HttpResponse::Forbidden().json(serde_json::json!({
        "error": "Not authorized"
    })))
}

async fn ensure_view_access(
    app_state: &AppState,
    claims: &Claims,
    current_user_id: i32,
    teacher_id: i32,
) -> Result<(), HttpResponse> {
    if claims.roles.contains(&"admin".to_string()) || current_user_id == teacher_id {
        return Ok(());
    }

    let is_related_student = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM teacher_student_relations
            WHERE teacher_user_id = $1 AND student_user_id = $2
        )",
    )
    .bind(teacher_id)
    .bind(current_user_id)
    .fetch_one(&app_state.db)
    .await
    .unwrap_or(false);

    let is_related_parent = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM parent_student_relations psr
            JOIN parents p ON p.user_id = psr.parent_user_id
            JOIN teacher_student_relations tsr ON psr.student_user_id = tsr.student_user_id
            WHERE psr.parent_user_id = $1 AND tsr.teacher_user_id = $2 AND p.status = 'active'
        )",
    )
    .bind(current_user_id)
    .bind(teacher_id)
    .fetch_one(&app_state.db)
    .await
    .unwrap_or(false);

    if is_related_student || is_related_parent {
        return Ok(());
    }

    Err(HttpResponse::Forbidden().json(serde_json::json!({
        "error": "Not authorized"
    })))
}

async fn validate_teacher(app_state: &AppState, teacher_id: i32) -> Result<(), HttpResponse> {
    let exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM teachers WHERE user_id = $1 AND status = 'active')",
    )
    .bind(teacher_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Failed to validate teacher: {}", e);
        HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Database error"
        }))
    })?;

    if !exists {
        return Err(HttpResponse::NotFound().json(serde_json::json!({
            "error": "Teacher not found"
        })));
    }

    Ok(())
}

async fn validate_students_belong_to_teacher(
    app_state: &AppState,
    teacher_id: i32,
    student_ids: &[i32],
) -> Result<(), HttpResponse> {
    if student_ids.is_empty() {
        return Err(HttpResponse::BadRequest().json(serde_json::json!({
            "error": "Group must include at least one student"
        })));
    }

    let count = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*)
         FROM students s
         JOIN teacher_student_relations tsr ON tsr.student_user_id = s.user_id
         WHERE s.status = 'active'
           AND tsr.teacher_user_id = $1
           AND s.user_id = ANY($2)",
    )
    .bind(teacher_id)
    .bind(student_ids)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Failed to validate students for teacher: {}", e);
        HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Database error"
        }))
    })?;

    if count as usize != student_ids.len() {
        return Err(HttpResponse::BadRequest().json(serde_json::json!({
            "error": "All group students must be active and belong to the teacher"
        })));
    }

    Ok(())
}

async fn load_group_students(app_state: &AppState, group_id: i32) -> Vec<GroupStudent> {
    sqlx::query_as::<_, GroupStudent>(
        "SELECT u.id AS user_id, u.username, u.full_name, u.email, u.phone
         FROM group_student_relations gsr
         JOIN users u ON u.id = gsr.student_user_id
         WHERE gsr.group_id = $1
         ORDER BY u.full_name, u.username",
    )
    .bind(group_id)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default()
}

#[get("/api/teachers/{teacher_id}/groups")]
async fn list_teacher_groups(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    query: web::Query<ListGroupsQuery>,
) -> impl Responder {
    let teacher_id = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    if let Err(response) =
        ensure_view_access(&app_state, &claims, current_user_id, teacher_id).await
    {
        return response;
    }

    let include_archived = query.include_archived.unwrap_or(false);

    let groups = match if include_archived {
        sqlx::query_as::<_, GroupRecord>(
            "SELECT id, teacher_user_id, name, status, archived_at, created_at, updated_at
             FROM student_groups
             WHERE teacher_user_id = $1
             ORDER BY (status = 'archived') ASC, created_at DESC",
        )
        .bind(teacher_id)
        .fetch_all(&app_state.db)
        .await
    } else {
        sqlx::query_as::<_, GroupRecord>(
            "SELECT id, teacher_user_id, name, status, archived_at, created_at, updated_at
             FROM student_groups
             WHERE teacher_user_id = $1 AND status = 'active'
             ORDER BY created_at DESC",
        )
        .bind(teacher_id)
        .fetch_all(&app_state.db)
        .await
    } {
        Ok(rows) => rows,
        Err(e) => {
            error!("Failed to load teacher groups: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    let mut response = Vec::with_capacity(groups.len());
    for group in groups {
        let students = load_group_students(&app_state, group.id).await;
        response.push(GroupResponse {
            id: group.id,
            teacher_user_id: group.teacher_user_id,
            name: group.name,
            status: group.status,
            archived_at: group.archived_at,
            created_at: group.created_at,
            updated_at: group.updated_at,
            students,
        });
    }

    HttpResponse::Ok().json(response)
}

#[post("/api/teachers/{teacher_id}/groups")]
async fn create_teacher_group(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    payload: web::Json<CreateGroupRequest>,
) -> impl Responder {
    let teacher_id = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    if let Err(response) = ensure_manage_access(&claims, current_user_id, teacher_id).await {
        return response;
    }

    if let Err(response) = validate_teacher(&app_state, teacher_id).await {
        return response;
    }

    let name = payload.name.trim();
    if name.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": "Group name is required"
        }));
    }

    if let Err(response) =
        validate_students_belong_to_teacher(&app_state, teacher_id, &payload.student_ids).await
    {
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

    let group_id = match sqlx::query_scalar::<_, i32>(
        "INSERT INTO student_groups (teacher_user_id, name)
         VALUES ($1, $2)
         RETURNING id",
    )
    .bind(teacher_id)
    .bind(name)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to create group: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create group"
            }));
        }
    };

    for student_id in &payload.student_ids {
        if let Err(e) = sqlx::query(
            "INSERT INTO group_student_relations (group_id, student_user_id)
             VALUES ($1, $2)",
        )
        .bind(group_id)
        .bind(student_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to add student to group: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create group"
            }));
        }
    }

    let feed_title = format!("{} Feed", name);
    if let Err(e) = sqlx::query(
        "INSERT INTO feeds (owner_type, owner_group_id, title)
         VALUES ('group', $1, $2)",
    )
    .bind(group_id)
    .bind(&feed_title)
    .execute(&mut *tx)
    .await
    {
        error!("Failed to create group feed: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create group feed"
        }));
    }

    if let Err(e) = tx.commit().await {
        error!("Failed to commit group create transaction: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to create group"
        }));
    }

    let group = match sqlx::query_as::<_, GroupRecord>(
        "SELECT id, teacher_user_id, name, status, archived_at, created_at, updated_at
         FROM student_groups
         WHERE id = $1",
    )
    .bind(group_id)
    .fetch_one(&app_state.db)
    .await
    {
        Ok(group) => group,
        Err(e) => {
            error!("Failed to load created group: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to create group"
            }));
        }
    };

    let students = load_group_students(&app_state, group.id).await;

    HttpResponse::Created().json(GroupResponse {
        id: group.id,
        teacher_user_id: group.teacher_user_id,
        name: group.name,
        status: group.status,
        archived_at: group.archived_at,
        created_at: group.created_at,
        updated_at: group.updated_at,
        students,
    })
}

#[put("/api/teachers/{teacher_id}/groups/{group_id}")]
async fn update_teacher_group(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
    payload: web::Json<UpdateGroupRequest>,
) -> impl Responder {
    let (teacher_id, group_id) = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    if let Err(response) = ensure_manage_access(&claims, current_user_id, teacher_id).await {
        return response;
    }

    let group_exists = match sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM student_groups
            WHERE id = $1 AND teacher_user_id = $2
        )",
    )
    .bind(group_id)
    .bind(teacher_id)
    .fetch_one(&app_state.db)
    .await
    {
        Ok(exists) => exists,
        Err(e) => {
            error!("Failed to validate group: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    if !group_exists {
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Group not found"
        }));
    }

    if let Some(student_ids) = payload.student_ids.as_ref() {
        if let Err(response) =
            validate_students_belong_to_teacher(&app_state, teacher_id, student_ids).await
        {
            return response;
        }
    }

    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start update transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    if let Some(archived) = payload.archived {
        let (status, archived_at): (&str, Option<DateTime<Utc>>) = if archived {
            ("archived", Some(Utc::now()))
        } else {
            ("active", None)
        };

        if let Err(e) = sqlx::query(
            "UPDATE student_groups
             SET status = $1,
                 archived_at = $2,
                 updated_at = NOW()
             WHERE id = $3 AND teacher_user_id = $4",
        )
        .bind(status)
        .bind(archived_at)
        .bind(group_id)
        .bind(teacher_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to update group status: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update group"
            }));
        }
    }

    if let Some(name) = payload.name.as_ref() {
        let name = name.trim();
        if name.is_empty() {
            let _ = tx.rollback().await;
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Group name is required"
            }));
        }

        if let Err(e) = sqlx::query(
            "UPDATE student_groups
             SET name = $1
             WHERE id = $2 AND teacher_user_id = $3",
        )
        .bind(name)
        .bind(group_id)
        .bind(teacher_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to update group name: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update group"
            }));
        }

        let feed_title = format!("{} Feed", name);
        if let Err(e) = sqlx::query(
            "UPDATE feeds
             SET title = $1
             WHERE owner_type = 'group' AND owner_group_id = $2",
        )
        .bind(feed_title)
        .bind(group_id)
        .execute(&mut *tx)
        .await
        {
            error!("Failed to update group feed title: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update group"
            }));
        }
    }

    if let Some(student_ids) = payload.student_ids.as_ref() {
        if let Err(e) = sqlx::query("DELETE FROM group_student_relations WHERE group_id = $1")
            .bind(group_id)
            .execute(&mut *tx)
            .await
        {
            error!("Failed to clear group students: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update group"
            }));
        }

        for student_id in student_ids {
            if let Err(e) = sqlx::query(
                "INSERT INTO group_student_relations (group_id, student_user_id)
                 VALUES ($1, $2)",
            )
            .bind(group_id)
            .bind(student_id)
            .execute(&mut *tx)
            .await
            {
                error!("Failed to update group students: {}", e);
                let _ = tx.rollback().await;
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to update group"
                }));
            }
        }
    }

    if let Err(e) = tx.commit().await {
        error!("Failed to commit group update: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to update group"
        }));
    }

    let group = match sqlx::query_as::<_, GroupRecord>(
        "SELECT id, teacher_user_id, name, status, archived_at, created_at, updated_at
         FROM student_groups
         WHERE id = $1",
    )
    .bind(group_id)
    .fetch_one(&app_state.db)
    .await
    {
        Ok(group) => group,
        Err(e) => {
            error!("Failed to load updated group: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to update group"
            }));
        }
    };

    let students = load_group_students(&app_state, group.id).await;

    HttpResponse::Ok().json(GroupResponse {
        id: group.id,
        teacher_user_id: group.teacher_user_id,
        name: group.name,
        status: group.status,
        archived_at: group.archived_at,
        created_at: group.created_at,
        updated_at: group.updated_at,
        students,
    })
}

#[delete("/api/teachers/{teacher_id}/groups/{group_id}")]
async fn delete_teacher_group(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
) -> impl Responder {
    let (teacher_id, group_id) = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    if let Err(response) = ensure_manage_access(&claims, current_user_id, teacher_id).await {
        return response;
    }

    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            error!("Failed to start delete transaction: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Database error"
            }));
        }
    };

    if let Err(e) =
        sqlx::query("DELETE FROM feeds WHERE owner_type = 'group' AND owner_group_id = $1")
            .bind(group_id)
            .execute(&mut *tx)
            .await
    {
        error!("Failed to delete group feed: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to delete group"
        }));
    }

    let result = match sqlx::query(
        "DELETE FROM student_groups
         WHERE id = $1 AND teacher_user_id = $2",
    )
    .bind(group_id)
    .bind(teacher_id)
    .execute(&mut *tx)
    .await
    {
        Ok(result) => result,
        Err(e) => {
            error!("Failed to delete group: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to delete group"
            }));
        }
    };

    if result.rows_affected() == 0 {
        let _ = tx.rollback().await;
        return HttpResponse::NotFound().json(serde_json::json!({
            "error": "Group not found"
        }));
    }

    if let Err(e) = tx.commit().await {
        error!("Failed to commit group delete: {}", e);
        return HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to delete group"
        }));
    }

    HttpResponse::Ok().json(serde_json::json!({
        "status": "deleted"
    }))
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(list_teacher_groups)
        .service(create_teacher_group)
        .service(update_teacher_group)
        .service(delete_teacher_group);
}
