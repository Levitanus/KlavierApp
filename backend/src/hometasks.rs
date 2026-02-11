use actix_web::{get, post, put, web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{FromRow, PgPool};

use crate::models::hometask::{HometaskStatus, HometaskType};
use crate::notification_builders::{
    build_hometask_accomplished_notification,
    build_hometask_assigned_notification,
    build_hometask_completed_notification,
    build_hometask_refreshed_notification,
    build_hometask_reopened_notification,
};
use crate::notifications::NotificationBody;
use crate::roles::helpers::verify_can_access_student;
use crate::users::{verify_token, Claims};
use crate::AppState;

#[derive(Deserialize)]
struct ChecklistItemInput {
    text: String,
}

#[derive(Deserialize)]
struct CreateHometaskRequest {
    student_id: i32,
    title: String,
    description: Option<String>,
    due_date: Option<DateTime<Utc>>,
    hometask_type: HometaskType,
    items: Option<Vec<ChecklistItemInput>>,
    repeat_every_days: Option<i32>,
}

#[derive(Deserialize)]
struct HometaskListQuery {
    status: Option<String>,
}

#[derive(Deserialize)]
struct UpdateHometaskStatusRequest {
    status: HometaskStatus,
}

#[derive(Deserialize)]
struct UpdateHometaskOrderRequest {
    hometask_ids: Vec<i32>,
}

#[derive(Deserialize)]
struct UpdateChecklistItemRequest {
    text: String,
    is_done: Option<bool>,
    progress: Option<i32>,
}

#[derive(Deserialize)]
struct UpdateChecklistRequest {
    items: Vec<UpdateChecklistItemRequest>,
}

#[derive(Serialize, FromRow)]
struct HometaskWithChecklist {
    id: i32,
    teacher_id: i32,
    student_id: i32,
    title: String,
    description: Option<String>,
    status: HometaskStatus,
    due_date: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    sort_order: i32,
    hometask_type: HometaskType,
    content_id: Option<i32>,
    checklist_items: Option<serde_json::Value>,
    teacher_name: Option<String>,
}

#[derive(FromRow)]
struct RepeatableHometask {
    id: i32,
    teacher_id: i32,
    student_id: i32,
    title: String,
    hometask_type: HometaskType,
    content_id: Option<i32>,
    repeat_every_days: i32,
    next_reset_at: DateTime<Utc>,
}

async fn insert_notification(
    db: &PgPool,
    user_id: i32,
    body: &NotificationBody,
    priority: &str,
) {
    let _ = sqlx::query(
        "INSERT INTO notifications (user_id, type, title, body, priority)
         VALUES ($1, $2, $3, $4, $5)",
    )
    .bind(user_id)
    .bind(&body.body_type)
    .bind(&body.title)
    .bind(serde_json::to_value(body).unwrap_or_default())
    .bind(priority)
    .execute(db)
    .await;
}

async fn fetch_teacher_name(db: &PgPool, teacher_id: i32) -> String {
    sqlx::query_scalar::<_, String>(
        "SELECT COALESCE(t.full_name, u.username)
         FROM users u
         LEFT JOIN teachers t ON u.id = t.user_id
         WHERE u.id = $1",
    )
    .bind(teacher_id)
    .fetch_optional(db)
    .await
    .unwrap_or(None)
    .unwrap_or_else(|| "Teacher".to_string())
}

async fn fetch_student_name(db: &PgPool, student_id: i32) -> String {
    sqlx::query_scalar::<_, String>(
        "SELECT COALESCE(s.full_name, u.username)
         FROM users u
         LEFT JOIN students s ON u.id = s.user_id
         WHERE u.id = $1",
    )
    .bind(student_id)
    .fetch_optional(db)
    .await
    .unwrap_or(None)
    .unwrap_or_else(|| "Student".to_string())
}

async fn fetch_parent_ids(db: &PgPool, student_id: i32) -> Vec<i32> {
    sqlx::query_scalar::<_, i32>(
        "SELECT parent_user_id FROM parent_student_relations WHERE student_user_id = $1",
    )
    .bind(student_id)
    .fetch_all(db)
    .await
    .unwrap_or_default()
}

async fn reset_hometask_items(
    db: &PgPool,
    content_id: i32,
    hometask_type: &HometaskType,
) {
    let items = sqlx::query_scalar::<_, serde_json::Value>(
        "SELECT items FROM hometask_checklists WHERE id = $1",
    )
    .bind(content_id)
    .fetch_optional(db)
    .await
    .unwrap_or(None);

    let items = match items.and_then(|value| value.as_array().cloned()) {
        Some(items) => items,
        None => return,
    };

    let updated_items = items
        .iter()
        .map(|item| {
            let text = item
                .get("text")
                .and_then(|value| value.as_str())
                .unwrap_or("")
                .to_string();
            
            match hometask_type {
                HometaskType::Checklist => json!({ "text": text, "is_done": false }),
                HometaskType::Progress => json!({ "text": text, "progress": 0 }),
                _ => json!({ "text": text, "is_done": false }),
            }
        })
        .collect::<Vec<_>>();

    let _ = sqlx::query(
        "UPDATE hometask_checklists SET items = $1 WHERE id = $2",
    )
    .bind(serde_json::to_value(updated_items).unwrap_or_default())
    .bind(content_id)
    .execute(db)
    .await;
}

async fn refresh_repeatable_hometasks(db: &PgPool, student_id: i32) {
    let tasks = sqlx::query_as::<_, RepeatableHometask>(
        "SELECT id, teacher_id, student_id, title, hometask_type, content_id,
                repeat_every_days, next_reset_at
         FROM hometasks
         WHERE student_id = $1
           AND repeat_every_days IS NOT NULL
           AND next_reset_at IS NOT NULL
                     AND next_reset_at <= NOW()
                     AND status <> 'accomplished_by_teacher'",
    )
    .bind(student_id)
    .fetch_all(db)
    .await
    .unwrap_or_default();

    if tasks.is_empty() {
        return;
    }

    let now = Utc::now();

    for task in tasks {
        if task.repeat_every_days <= 0 {
            continue;
        }

        let interval = chrono::Duration::days(task.repeat_every_days as i64);
        let mut next_reset_at = task.next_reset_at;
        while next_reset_at <= now {
            next_reset_at = next_reset_at + interval;
        }

        // Reset items based on hometask type
        match task.hometask_type {
            HometaskType::Checklist | HometaskType::Progress => {
                if let Some(content_id) = task.content_id {
                    reset_hometask_items(db, content_id, &task.hometask_type).await;
                }
            }
            _ => {}
        }

        let _ = sqlx::query(
            "UPDATE hometasks
             SET status = 'assigned', next_reset_at = $1
             WHERE id = $2",
        )
        .bind(next_reset_at)
        .bind(task.id)
        .execute(db)
        .await;

        let teacher_name = fetch_teacher_name(db, task.teacher_id).await;
        let refreshed_body = build_hometask_refreshed_notification(
            task.id,
            &task.title,
            &teacher_name,
            task.student_id,
        );
        insert_notification(db, task.student_id, &refreshed_body, "normal").await;
        let parent_ids = fetch_parent_ids(db, task.student_id).await;
        for parent_id in parent_ids {
            insert_notification(db, parent_id, &refreshed_body, "normal").await;
        }
    }
}

pub fn init_routes(cfg: &mut web::ServiceConfig) {
    cfg
        .service(create_hometask)
        .service(list_student_hometasks)
        .service(get_hometask)
        .service(update_hometask_checklist)
        .service(update_hometask_status)
        .service(update_hometask_order);
}

#[post("/api/hometasks")]
async fn create_hometask(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    payload: web::Json<CreateHometaskRequest>,
) -> impl Responder {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state.db).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    let is_admin = claims.roles.contains(&"admin".to_string());
    let is_teacher = claims.roles.contains(&"teacher".to_string());

    if !is_admin && !is_teacher {
        return HttpResponse::Forbidden().json(json!({
            "error": "Teacher access required"
        }));
    }

    if !is_admin {
        let has_relation = match verify_teacher_student_relation(
            current_user_id,
            payload.student_id,
            &app_state.db,
        )
        .await
        {
            Ok(result) => result,
            Err(response) => return response,
        };

        if !has_relation {
            return HttpResponse::Forbidden().json(json!({
                "error": "Not authorized to assign hometasks to this student"
            }));
        }
    }

    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }));
        }
    };

    let content_id: Option<i32>;

    match payload.hometask_type {
        HometaskType::Checklist => {
            let items = match payload.items.as_ref() {
                Some(items) if !items.is_empty() => items,
                _ => {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(json!({
                        "error": "Checklist items cannot be empty"
                    }));
                }
            };

            let checklist_items = items
                .iter()
                .map(|item| json!({ "text": item.text, "is_done": false }))
                .collect::<Vec<_>>();

            let checklist_items_value = match serde_json::to_value(checklist_items) {
                Ok(value) => value,
                Err(_) => {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(json!({
                        "error": "Invalid checklist items"
                    }));
                }
            };

            let checklist_id = match sqlx::query_scalar::<_, i32>(
                "INSERT INTO hometask_checklists (items) VALUES ($1) RETURNING id",
            )
            .bind(&checklist_items_value)
            .fetch_one(&mut *tx)
            .await
            {
                Ok(id) => id,
                Err(e) => {
                    eprintln!("Failed to create checklist: {}", e);
                    let _ = tx.rollback().await;
                    return HttpResponse::InternalServerError().json(json!({
                        "error": "Failed to create checklist"
                    }));
                }
            };

            content_id = Some(checklist_id);
        }
        HometaskType::Progress => {
            let items = match payload.items.as_ref() {
                Some(items) if !items.is_empty() => items,
                _ => {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(json!({
                        "error": "Progress items cannot be empty"
                    }));
                }
            };

            let progress_items = items
                .iter()
                .map(|item| json!({ "text": item.text, "progress": 0 }))
                .collect::<Vec<_>>();

            let progress_items_value = match serde_json::to_value(progress_items) {
                Ok(value) => value,
                Err(_) => {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(json!({
                        "error": "Invalid progress items"
                    }));
                }
            };

            let checklist_id = match sqlx::query_scalar::<_, i32>(
                "INSERT INTO hometask_checklists (items) VALUES ($1) RETURNING id",
            )
            .bind(&progress_items_value)
            .fetch_one(&mut *tx)
            .await
            {
                Ok(id) => id,
                Err(e) => {
                    eprintln!("Failed to create progress items: {}", e);
                    let _ = tx.rollback().await;
                    return HttpResponse::InternalServerError().json(json!({
                        "error": "Failed to create progress items"
                    }));
                }
            };

            content_id = Some(checklist_id);
        }
        HometaskType::Simple => {
            content_id = None;
        }
        _ => {
            let _ = tx.rollback().await;
            return HttpResponse::BadRequest().json(json!({
                "error": "Unsupported hometask type"
            }));
        }
    }

    let next_sort_order = match sqlx::query_scalar::<_, i32>(
        "SELECT COALESCE(MAX(sort_order), 0) + 1 FROM hometasks WHERE student_id = $1",
    )
    .bind(payload.student_id)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(order) => order,
        Err(e) => {
            eprintln!("Failed to get sort order: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(json!({
                "error": "Failed to create hometask"
            }));
        }
    };

    let repeat_every_days = payload.repeat_every_days.filter(|value| *value > 0);
    let next_reset_at = repeat_every_days
        .map(|value| Utc::now() + chrono::Duration::days(value as i64));

    let hometask_id = match sqlx::query_scalar::<_, i32>(
        "INSERT INTO hometasks (teacher_id, student_id, title, description, due_date, sort_order, hometask_type, content_id, repeat_every_days, next_reset_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id",
    )
    .bind(current_user_id)
    .bind(payload.student_id)
    .bind(&payload.title)
    .bind(&payload.description)
    .bind(payload.due_date)
    .bind(next_sort_order)
    .bind(payload.hometask_type.clone())
    .bind(content_id)
    .bind(repeat_every_days)
    .bind(next_reset_at)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Failed to create hometask: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(json!({
                "error": "Failed to create hometask"
            }));
        }
    };

    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit transaction: {}", e);
        return HttpResponse::InternalServerError().json(json!({
            "error": "Failed to create hometask"
        }));
    }

    let teacher_name = fetch_teacher_name(&app_state.db, current_user_id).await;
    let parent_ids = fetch_parent_ids(&app_state.db, payload.student_id).await;
    let due_date = payload
        .due_date
        .map(|date| date.format("%Y-%m-%d").to_string());
    let assigned_body = build_hometask_assigned_notification(
        hometask_id,
        &payload.title,
        &teacher_name,
        due_date.as_deref(),
        payload.student_id,
    );

    insert_notification(&app_state.db, payload.student_id, &assigned_body, "normal").await;
    for parent_id in parent_ids {
        insert_notification(&app_state.db, parent_id, &assigned_body, "normal").await;
    }

    HttpResponse::Created().json(json!({ "id": hometask_id }))
}

#[get("/api/students/{student_id}/hometasks")]
async fn list_student_hometasks(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    query: web::Query<HometaskListQuery>,
) -> impl Responder {
    let student_id = path.into_inner();

    if let Err(response) = verify_can_access_student(&req, &app_state, student_id).await {
        return response;
    }

    refresh_repeatable_hometasks(&app_state.db, student_id).await;

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state.db).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    let is_admin = claims.roles.contains(&"admin".to_string());
    let is_teacher = claims.roles.contains(&"teacher".to_string());

    let teacher_filter = if !is_admin && is_teacher {
        Some(current_user_id)
    } else {
        None
    };

    let status_filter = match query.status.as_deref().unwrap_or("active") {
        "active" => vec!["assigned".to_string(), "completed_by_student".to_string()],
        "archived" => vec!["accomplished_by_teacher".to_string()],
        _ => {
            return HttpResponse::BadRequest().json(json!({
                "error": "Invalid status filter"
            }))
        }
    };

    let hometasks = sqlx::query_as::<_, HometaskWithChecklist>(
        "SELECT h.id, h.teacher_id, h.student_id, h.title, h.description, h.status, h.due_date,
                 h.created_at, h.updated_at, h.sort_order, h.hometask_type, h.content_id,
                 c.items AS checklist_items,
                 COALESCE(t.full_name, u.username) AS teacher_name
         FROM hometasks h
         LEFT JOIN hometask_checklists c
            ON (h.hometask_type = 'checklist' OR h.hometask_type = 'progress') AND h.content_id = c.id
            LEFT JOIN teachers t ON h.teacher_id = t.user_id
            LEFT JOIN users u ON h.teacher_id = u.id
            WHERE h.student_id = $1 AND h.status = ANY($2::hometask_status[])
              AND ($3::int IS NULL OR h.teacher_id = $3)
         ORDER BY h.sort_order ASC, h.created_at DESC",
    )
    .bind(student_id)
    .bind(status_filter)
     .bind(teacher_filter)
    .fetch_all(&app_state.db)
    .await;

    match hometasks {
        Ok(list) => HttpResponse::Ok().json(list),
        Err(e) => {
            eprintln!("Failed to fetch hometasks: {}", e);
            HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }))
        }
    }
}

#[get("/api/hometasks/{hometask_id}")]
async fn get_hometask(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
) -> impl Responder {
    let hometask_id = path.into_inner();

    let (student_id, teacher_id) = match sqlx::query_as::<_, (i32, i32)>(
        "SELECT student_id, teacher_id FROM hometasks WHERE id = $1",
    )
    .bind(hometask_id)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(row)) => row,
        Ok(None) => {
            return HttpResponse::NotFound().json(json!({
                "error": "Hometask not found"
            }))
        }
        Err(e) => {
            eprintln!("Failed to fetch hometask: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }));
        }
    };

    if let Err(response) = verify_can_access_student(&req, &app_state, student_id).await {
        return response;
    }

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state.db).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    let is_admin = claims.roles.contains(&"admin".to_string());
    let is_teacher = claims.roles.contains(&"teacher".to_string());

    if !is_admin && is_teacher && current_user_id != teacher_id {
        return HttpResponse::Forbidden().json(json!({
            "error": "Not authorized to access this hometask"
        }));
    }

    let hometask = sqlx::query_as::<_, HometaskWithChecklist>(
        "SELECT h.id, h.teacher_id, h.student_id, h.title, h.description, h.status, h.due_date,
                h.created_at, h.updated_at, h.sort_order, h.hometask_type, h.content_id,
                c.items AS checklist_items
         FROM hometasks h
         LEFT JOIN hometask_checklists c
            ON (h.hometask_type = 'checklist' OR h.hometask_type = 'progress') AND h.content_id = c.id
         WHERE h.id = $1",
    )
    .bind(hometask_id)
    .fetch_optional(&app_state.db)
    .await;

    match hometask {
        Ok(Some(item)) => HttpResponse::Ok().json(item),
        Ok(None) => HttpResponse::NotFound().json(json!({
            "error": "Hometask not found"
        })),
        Err(e) => {
            eprintln!("Failed to fetch hometask: {}", e);
            HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }))
        }
    }
}

#[put("/api/hometasks/{hometask_id}/checklist")]
async fn update_hometask_checklist(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    payload: web::Json<UpdateChecklistRequest>,
) -> impl Responder {
    let hometask_id = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state.db).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    let hometask = match sqlx::query_as::<_, (i32, i32, HometaskStatus, HometaskType, Option<i32>)>(
        "SELECT student_id, teacher_id, status, hometask_type, content_id FROM hometasks WHERE id = $1",
    )
    .bind(hometask_id)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(row)) => row,
        Ok(None) => {
            return HttpResponse::NotFound().json(json!({
                "error": "Hometask not found"
            }))
        }
        Err(e) => {
            eprintln!("Failed to fetch hometask: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }));
        }
    };

    let (student_id, teacher_id, status, hometask_type, content_id) = hometask;

    eprintln!(
        "Checklist update: user_id={}, student_id={}, roles={:?}",
        current_user_id,
        student_id,
        claims.roles
    );

    let is_student = claims.roles.contains(&"student".to_string())
        && current_user_id == student_id;
    let is_parent = claims.roles.contains(&"parent".to_string())
        && verify_can_access_student(&req, &app_state, student_id).await.is_ok();
    let is_teacher = claims.roles.contains(&"teacher".to_string());

    if hometask_type == HometaskType::Progress || hometask_type == HometaskType::Checklist {
        if !is_student && !is_parent && !is_teacher {
            return HttpResponse::Forbidden().json(json!({
                "error": "Not authorized to update checklist items"
            }));
        }

        if is_teacher && current_user_id != teacher_id {
            let has_relation = match verify_teacher_student_relation(
                current_user_id,
                student_id,
                &app_state.db,
            )
            .await
            {
                Ok(result) => result,
                Err(response) => return response,
            };

            if !has_relation {
                return HttpResponse::Forbidden().json(json!({
                    "error": "Not authorized to update checklist items"
                }));
            }
        }
    }

    if status == HometaskStatus::AccomplishedByTeacher {
        return HttpResponse::BadRequest().json(json!({
            "error": "Cannot update archived hometasks"
        }));
    }

    if hometask_type != HometaskType::Checklist && hometask_type != HometaskType::Progress {
        return HttpResponse::BadRequest().json(json!({
            "error": "Hometask is not a checklist or progress task"
        }));
    }

    let content_id = match content_id {
        Some(id) => id,
        None => {
            return HttpResponse::BadRequest().json(json!({
                "error": "Checklist content is missing"
            }));
        }
    };

    if payload.items.is_empty() {
        return HttpResponse::BadRequest().json(json!({
            "error": "Checklist items cannot be empty"
        }));
    }

    let updated_items = if hometask_type == HometaskType::Checklist {
        let invalid = payload.items.iter().any(|item| item.is_done.is_none());
        if invalid {
            return HttpResponse::BadRequest().json(json!({
                "error": "Checklist items must include is_done"
            }));
        }

        payload
            .items
            .iter()
            .map(|item| {
                json!({
                    "text": item.text,
                    "is_done": item.is_done.unwrap_or(false)
                })
            })
            .collect::<Vec<_>>()
    } else {
        let mut updated = Vec::with_capacity(payload.items.len());
        for item in &payload.items {
            let progress = match item.progress {
                Some(value) if (0..=4).contains(&value) => value,
                _ => {
                    return HttpResponse::BadRequest().json(json!({
                        "error": "Progress items must be between 0 and 4"
                    }));
                }
            };
            updated.push(json!({ "text": item.text, "progress": progress }));
        }
        updated
    };

    let updated_value = match serde_json::to_value(updated_items) {
        Ok(value) => value,
        Err(_) => {
            return HttpResponse::BadRequest().json(json!({
                "error": "Invalid checklist items"
            }))
        }
    };

    let result = sqlx::query(
        "UPDATE hometask_checklists SET items = $1 WHERE id = $2",
    )
    .bind(updated_value)
    .bind(content_id)
    .execute(&app_state.db)
    .await;

    match result {
        Ok(_) => HttpResponse::Ok().json(json!({ "status": "updated" })),
        Err(e) => {
            eprintln!("Failed to update checklist: {}", e);
            HttpResponse::InternalServerError().json(json!({
                "error": "Failed to update checklist"
            }))
        }
    }
}

#[put("/api/hometasks/{hometask_id}/status")]
async fn update_hometask_status(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    payload: web::Json<UpdateHometaskStatusRequest>,
) -> impl Responder {
    let hometask_id = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state.db).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    let hometask = match sqlx::query_as::<_, (i32, i32, String, Option<DateTime<Utc>>, HometaskStatus, Option<i32>, Option<DateTime<Utc>>)>(
        "SELECT teacher_id, student_id, title, due_date, status, repeat_every_days, next_reset_at
         FROM hometasks WHERE id = $1",
    )
    .bind(hometask_id)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(row)) => row,
        Ok(None) => {
            return HttpResponse::NotFound().json(json!({
                "error": "Hometask not found"
            }))
        }
        Err(e) => {
            eprintln!("Failed to fetch hometask: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }));
        }
    };

    let (teacher_id, student_id, task_title, due_date, current_status, repeat_every_days, next_reset_at) = hometask;

    match payload.status {
        HometaskStatus::CompletedByStudent => {
            eprintln!(
                "Hometask status update: user_id={}, student_id={}, roles={:?}, status={:?}",
                current_user_id,
                student_id,
                claims.roles,
                payload.status
            );

            let is_student = claims.roles.contains(&"student".to_string())
                && current_user_id == student_id;
            let is_parent = claims.roles.contains(&"parent".to_string())
                && verify_can_access_student(&req, &app_state, student_id).await.is_ok();

            if !is_student && !is_parent {
                return HttpResponse::Forbidden().json(json!({
                    "error": "Only the student can complete this hometask"
                }));
            }

            if current_status != HometaskStatus::Assigned {
                return HttpResponse::BadRequest().json(json!({
                    "error": "Hometask is not in an assignable state"
                }));
            }
        }
        HometaskStatus::AccomplishedByTeacher => {
            let is_admin = claims.roles.contains(&"admin".to_string());
            let is_teacher = claims.roles.contains(&"teacher".to_string());

            if !is_admin && !is_teacher {
                return HttpResponse::Forbidden().json(json!({
                    "error": "Teacher access required"
                }));
            }

            if !is_admin {
                let has_relation = match verify_teacher_student_relation(
                    current_user_id,
                    student_id,
                    &app_state.db,
                )
                .await
                {
                    Ok(result) => result,
                    Err(response) => return response,
                };

                if !has_relation || current_user_id != teacher_id {
                    return HttpResponse::Forbidden().json(json!({
                        "error": "Not authorized to accomplish this hometask"
                    }));
                }
            }

            if current_status == HometaskStatus::AccomplishedByTeacher {
                return HttpResponse::Ok().json(json!({ "status": "updated" }));
            }
        }
        HometaskStatus::Assigned => {
            let is_admin = claims.roles.contains(&"admin".to_string());
            let is_teacher = claims.roles.contains(&"teacher".to_string());

            if !is_admin && !is_teacher {
                return HttpResponse::Forbidden().json(json!({
                    "error": "Teacher access required"
                }));
            }

            if !is_admin {
                let has_relation = match verify_teacher_student_relation(
                    current_user_id,
                    student_id,
                    &app_state.db,
                )
                .await
                {
                    Ok(result) => result,
                    Err(response) => return response,
                };

                if !has_relation || current_user_id != teacher_id {
                    return HttpResponse::Forbidden().json(json!({
                        "error": "Not authorized to reopen this hometask"
                    }));
                }
            }

            if current_status == HometaskStatus::Assigned {
                return HttpResponse::Ok().json(json!({ "status": "updated" }));
            }

            if current_status != HometaskStatus::CompletedByStudent
                && current_status != HometaskStatus::AccomplishedByTeacher
            {
                return HttpResponse::BadRequest().json(json!({
                    "error": "Hometask cannot be reopened from this state"
                }));
            }
        }
    }

    let mut next_reset_update: Option<DateTime<Utc>> = None;
    if payload.status == HometaskStatus::Assigned {
        if let Some(repeat_days) = repeat_every_days {
            if repeat_days > 0 {
                let now = Utc::now();
                let is_stale = next_reset_at.map(|value| value <= now).unwrap_or(true);
                if is_stale {
                    next_reset_update = Some(now + chrono::Duration::days(repeat_days as i64));
                }
            }
        }
    }

    let result = if let Some(next_reset_at) = next_reset_update {
        sqlx::query(
            "UPDATE hometasks SET status = $1, next_reset_at = $2 WHERE id = $3",
        )
        .bind(payload.status.clone())
        .bind(next_reset_at)
        .bind(hometask_id)
        .execute(&app_state.db)
        .await
    } else {
        sqlx::query(
            "UPDATE hometasks SET status = $1 WHERE id = $2",
        )
        .bind(payload.status.clone())
        .bind(hometask_id)
        .execute(&app_state.db)
        .await
    };

    match result {
        Ok(_) => {
            match payload.status {
                HometaskStatus::CompletedByStudent => {
                    let student_name = fetch_student_name(&app_state.db, student_id).await;
                    let completed_body = build_hometask_completed_notification(
                        hometask_id,
                        &task_title,
                        &student_name,
                        student_id,
                    );
                    insert_notification(&app_state.db, teacher_id, &completed_body, "normal").await;
                }
                HometaskStatus::AccomplishedByTeacher => {
                    let teacher_name = fetch_teacher_name(&app_state.db, teacher_id).await;
                    let accomplished_body = build_hometask_accomplished_notification(
                        hometask_id,
                        &task_title,
                        &teacher_name,
                        student_id,
                    );
                    insert_notification(&app_state.db, student_id, &accomplished_body, "normal").await;
                    let parent_ids = fetch_parent_ids(&app_state.db, student_id).await;
                    for parent_id in parent_ids {
                        insert_notification(&app_state.db, parent_id, &accomplished_body, "normal").await;
                    }
                }
                HometaskStatus::Assigned => {
                    let teacher_name = fetch_teacher_name(&app_state.db, teacher_id).await;
                    let reopened_body = build_hometask_reopened_notification(
                        hometask_id,
                        &task_title,
                        &teacher_name,
                        student_id,
                    );
                    insert_notification(&app_state.db, student_id, &reopened_body, "normal").await;
                    let parent_ids = fetch_parent_ids(&app_state.db, student_id).await;
                    for parent_id in parent_ids {
                        insert_notification(&app_state.db, parent_id, &reopened_body, "normal").await;
                    }
                }
                _ => {}
            }

            HttpResponse::Ok().json(json!({ "status": "updated" }))
        }
        Err(e) => {
            eprintln!("Failed to update hometask status: {}", e);
            HttpResponse::InternalServerError().json(json!({
                "error": "Failed to update hometask"
            }))
        }
    }
}

#[put("/api/students/{student_id}/hometasks/order")]
async fn update_hometask_order(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<i32>,
    payload: web::Json<UpdateHometaskOrderRequest>,
) -> impl Responder {
    let student_id = path.into_inner();

    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(response) => return response,
    };

    let current_user_id = match get_current_user_id(&claims, &app_state.db).await {
        Ok(id) => id,
        Err(response) => return response,
    };

    let is_admin = claims.roles.contains(&"admin".to_string());
    let is_teacher = claims.roles.contains(&"teacher".to_string());

    if !is_admin && !is_teacher {
        return HttpResponse::Forbidden().json(json!({
            "error": "Teacher access required"
        }));
    }

    if !is_admin {
        let has_relation = match verify_teacher_student_relation(
            current_user_id,
            student_id,
            &app_state.db,
        )
        .await
        {
            Ok(result) => result,
            Err(response) => return response,
        };

        if !has_relation {
            return HttpResponse::Forbidden().json(json!({
                "error": "Not authorized to reorder hometasks for this student"
            }));
        }
    }

    if payload.hometask_ids.is_empty() {
        return HttpResponse::BadRequest().json(json!({
            "error": "Hometask order cannot be empty"
        }));
    }

    let count = if !is_admin && is_teacher {
        sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM hometasks
             WHERE student_id = $1 AND id = ANY($2) AND teacher_id = $3",
        )
        .bind(student_id)
        .bind(&payload.hometask_ids)
        .bind(current_user_id)
        .fetch_one(&app_state.db)
        .await
    } else {
        sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM hometasks WHERE student_id = $1 AND id = ANY($2)",
        )
        .bind(student_id)
        .bind(&payload.hometask_ids)
        .fetch_one(&app_state.db)
        .await
    };

    let count = match count {
        Ok(count) => count,
        Err(e) => {
            eprintln!("Failed to validate hometask order: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }));
        }
    };

    if count as usize != payload.hometask_ids.len() {
        return HttpResponse::BadRequest().json(json!({
            "error": "Hometask order includes invalid items"
        }));
    }

    let mut tx = match app_state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Failed to start transaction: {}", e);
            return HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            }));
        }
    };

    for (index, hometask_id) in payload.hometask_ids.iter().enumerate() {
        let update_query = if !is_admin && is_teacher {
            sqlx::query(
                "UPDATE hometasks SET sort_order = $1 WHERE id = $2 AND student_id = $3 AND teacher_id = $4",
            )
            .bind(index as i32)
            .bind(hometask_id)
            .bind(student_id)
            .bind(current_user_id)
        } else {
            sqlx::query(
                "UPDATE hometasks SET sort_order = $1 WHERE id = $2 AND student_id = $3",
            )
            .bind(index as i32)
            .bind(hometask_id)
            .bind(student_id)
        };

        if let Err(e) = update_query.execute(&mut *tx).await {
            eprintln!("Failed to update hometask order: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(json!({
                "error": "Failed to update hometask order"
            }));
        }
    }

    if let Err(e) = tx.commit().await {
        eprintln!("Failed to commit hometask order update: {}", e);
        return HttpResponse::InternalServerError().json(json!({
            "error": "Failed to update hometask order"
        }));
    }

    HttpResponse::Ok().json(json!({ "status": "updated" }))
}

async fn get_current_user_id(claims: &Claims, db: &PgPool) -> Result<i32, HttpResponse> {
    let user_id = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1",
    )
    .bind(&claims.sub)
    .fetch_optional(db)
    .await;

    match user_id {
        Ok(Some(id)) => Ok(id),
        _ => Err(HttpResponse::Unauthorized().json(json!({
            "error": "User not found"
        }))),
    }
}

async fn verify_teacher_student_relation(
    teacher_id: i32,
    student_id: i32,
    db: &PgPool,
) -> Result<bool, HttpResponse> {
    let relation_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM teacher_student_relations tsr
            JOIN teachers t ON tsr.teacher_user_id = t.user_id
            JOIN students s ON tsr.student_user_id = s.user_id
            WHERE tsr.teacher_user_id = $1 AND tsr.student_user_id = $2
              AND t.status = 'active' AND s.status = 'active'
        )",
    )
    .bind(teacher_id)
    .bind(student_id)
    .fetch_one(db)
    .await;

    match relation_exists {
        Ok(exists) => Ok(exists),
        Err(e) => {
            eprintln!("Failed to verify teacher-student relation: {}", e);
            Err(HttpResponse::InternalServerError().json(json!({
                "error": "Database error"
            })))
        }
    }
}
