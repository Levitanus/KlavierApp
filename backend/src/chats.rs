use actix_web::{web, HttpRequest, HttpResponse, Result};
use chrono::{DateTime, Utc};
use log::{debug, error, warn};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{FromRow, PgPool};
use std::collections::{HashMap, HashSet};

use crate::notifications::{ContentBlock, NotificationBody, NotificationContent};
use crate::push;
use crate::users::verify_token;
use crate::websockets;
use crate::AppState;

// ============================================================================
// Helper functions
// ============================================================================

async fn extract_user_id_from_token(req: &HttpRequest, app_state: &AppState) -> Result<i32> {
    let claims = match verify_token(req, app_state) {
        Ok(claims) => claims,
        Err(_response) => {
            return Err(actix_web::error::ErrorUnauthorized(
                "Invalid or missing token",
            ))
        }
    };

    let user_id = sqlx::query_scalar::<_, i32>("SELECT id FROM users WHERE username = $1")
        .bind(&claims.sub)
        .fetch_optional(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error getting user_id: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to get user information")
        })?
        .ok_or_else(|| actix_web::error::ErrorUnauthorized("User not found"))?;

    Ok(user_id)
}

async fn fetch_user_display_name(db: &PgPool, user_id: i32) -> String {
    sqlx::query_scalar::<_, String>(
        "SELECT COALESCE(full_name, username)
         FROM users
         WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(db)
    .await
    .unwrap_or(None)
    .unwrap_or_else(|| "Unknown".to_string())
}

fn build_chat_notification(
    sender_name: &str,
    message: &str,
    thread_id: i32,
    sender_id: i32,
) -> NotificationBody {
    NotificationBody {
        body_type: "chat_message".to_string(),
        title: format!("New message from {}", sender_name),
        route: Some(format!("/chat/{}", thread_id)),
        content: NotificationContent {
            blocks: vec![ContentBlock::Text {
                text: message.to_string(),
                style: Some("body".to_string()),
            }],
            actions: None,
        },
        metadata: Some(json!({
            "thread_id": thread_id,
            "sender_id": sender_id,
        })),
    }
}

fn chat_message_preview(body: &serde_json::Value) -> String {
    let mut text = String::new();
    if let Some(ops) = body.get("ops").and_then(|value| value.as_array()) {
        for op in ops {
            if let Some(insert) = op.get("insert").and_then(|value| value.as_str()) {
                text.push_str(insert);
            }
        }
    }

    let trimmed = text.trim().to_string();
    if trimmed.is_empty() {
        return "New message".to_string();
    }

    let limit = 180;
    if trimmed.len() <= limit {
        return trimmed;
    }

    let mut cut = trimmed.chars().take(limit).collect::<String>();
    cut.push_str("...");
    cut
}

fn is_valid_attachment_type(value: &str) -> bool {
    matches!(value, "image" | "audio" | "voice" | "video" | "file")
}

async fn load_attachments_for_messages(
    db: &PgPool,
    message_ids: &[i32],
) -> Result<HashMap<i32, Vec<ChatAttachmentResponse>>, sqlx::Error> {
    if message_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let rows = sqlx::query_as::<_, ChatAttachmentRow>(
        "SELECT cma.message_id,
                cma.media_id,
                cma.attachment_type::text as attachment_type,
                mf.public_url,
                mf.mime_type,
                mf.size_bytes
         FROM chat_message_attachments cma
         JOIN media_files mf ON cma.media_id = mf.id
         WHERE cma.message_id = ANY($1)
         ORDER BY cma.id",
    )
    .bind(message_ids)
    .fetch_all(db)
    .await?;

    let mut map: HashMap<i32, Vec<ChatAttachmentResponse>> = HashMap::new();
    for row in rows {
        map.entry(row.message_id)
            .or_default()
            .push(ChatAttachmentResponse {
                media_id: row.media_id,
                attachment_type: row.attachment_type,
                url: row.public_url,
                mime_type: row.mime_type,
                size_bytes: row.size_bytes,
            });
    }

    Ok(map)
}

async fn store_message_attachments(
    db: &PgPool,
    user_id: i32,
    message_id: i32,
    attachments: &[ChatAttachmentInput],
) -> Result<Vec<ChatAttachmentResponse>, HttpResponse> {
    if attachments.is_empty() {
        return Ok(Vec::new());
    }

    let mut stored = Vec::new();

    for attachment in attachments {
        if !is_valid_attachment_type(&attachment.attachment_type) {
            return Err(HttpResponse::BadRequest().json(json!({
                "error": "Invalid attachment type"
            })));
        }

        let media = sqlx::query_as::<_, MediaRow>(
            "SELECT id, public_url, mime_type, size_bytes, media_type::text as media_type
             FROM media_files
             WHERE id = $1 AND created_by_user_id = $2",
        )
        .bind(attachment.media_id)
        .bind(user_id)
        .fetch_optional(db)
        .await
        .map_err(|e| {
            HttpResponse::InternalServerError().json(json!({
                "error": format!("Failed to load media: {}", e)
            }))
        })?
        .ok_or_else(|| {
            HttpResponse::BadRequest().json(json!({
                "error": "Media not found"
            }))
        })?;

        let is_voice = attachment.attachment_type == "voice";
        let matches_type = attachment.attachment_type == media.media_type
            || (is_voice && media.media_type == "audio")
            || attachment.attachment_type == "file";

        if !matches_type {
            return Err(HttpResponse::BadRequest().json(json!({
                "error": "Attachment type does not match media type"
            })));
        }

        sqlx::query(
            "INSERT INTO chat_message_attachments (message_id, media_id, attachment_type)
             VALUES ($1, $2, $3::chat_attachment_type)",
        )
        .bind(message_id)
        .bind(media.id)
        .bind(&attachment.attachment_type)
        .execute(db)
        .await
        .map_err(|e| {
            HttpResponse::InternalServerError().json(json!({
                "error": format!("Failed to save attachment: {}", e)
            }))
        })?;

        stored.push(ChatAttachmentResponse {
            media_id: media.id,
            attachment_type: attachment.attachment_type.clone(),
            url: media.public_url,
            mime_type: media.mime_type,
            size_bytes: media.size_bytes,
        });
    }

    Ok(stored)
}
// ============================================================================
// Models
// ============================================================================

#[derive(Debug, Serialize, FromRow, Clone)]
pub struct ChatThread {
    pub id: i32,
    pub participant_a_id: i32,
    pub participant_b_id: Option<i32>,
    pub is_admin_chat: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow, Clone)]
pub struct ChatMessage {
    pub id: i32,
    pub thread_id: i32,
    pub sender_id: i32,
    pub body: serde_json::Value, // Quill JSON
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow, Clone)]
pub struct MessageReceipt {
    pub id: i32,
    pub message_id: i32,
    pub recipient_id: i32,
    pub state: String, // 'sent', 'delivered', 'read'
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow, Clone)]
pub struct ChatPresence {
    pub user_id: i32,
    pub is_online: bool,
    pub last_seen_at: DateTime<Utc>,
}

// Response DTOs
#[derive(Debug, Serialize, Clone)]
pub struct ChatThreadResponse {
    pub id: i32,
    pub participant_a_id: i32,
    pub participant_b_id: Option<i32>,
    pub peer_user_id: Option<i32>, // For UI convenience: the "other" participant
    pub peer_name: Option<String>,
    pub is_admin_chat: bool,
    pub last_message: Option<ChatMessageResponse>,
    pub updated_at: DateTime<Utc>,
    pub unread_count: i32,
}

#[derive(Debug, Serialize, Clone)]
pub struct ChatMessageResponse {
    pub id: i32,
    pub sender_id: i32,
    pub sender_name: String,
    pub body: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub receipts: Vec<ReceiptResponse>,
    pub attachments: Vec<ChatAttachmentResponse>,
}

#[derive(Debug, Serialize, Clone)]
pub struct ReceiptResponse {
    pub recipient_id: i32,
    pub state: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Clone)]
pub struct ChatAttachmentResponse {
    pub media_id: i32,
    pub attachment_type: String,
    pub url: String,
    pub mime_type: String,
    pub size_bytes: i32,
}

#[derive(Debug, FromRow)]
struct ChatAttachmentRow {
    pub message_id: i32,
    pub media_id: i32,
    pub attachment_type: String,
    pub public_url: String,
    pub mime_type: String,
    pub size_bytes: i32,
}

#[derive(Debug, FromRow)]
struct MediaRow {
    pub id: i32,
    pub public_url: String,
    pub mime_type: String,
    pub size_bytes: i32,
    pub media_type: String,
}

#[derive(Debug, Serialize, Clone, FromRow)]
pub struct AvailableChatUser {
    pub user_id: i32,
    pub username: String,
    pub full_name: String,
    pub profile_image: Option<String>,
}

// Request DTOs
#[derive(Debug, Deserialize)]
pub struct CreateMessageRequest {
    pub body: serde_json::Value, // Quill JSON
    pub attachments: Option<Vec<ChatAttachmentInput>>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateMessageRequest {
    pub body: serde_json::Value, // Quill JSON
}

#[derive(Debug, Deserialize)]
pub struct ChatAttachmentInput {
    pub media_id: i32,
    pub attachment_type: String,
}

#[derive(Debug, Deserialize)]
pub struct StartThreadRequest {
    pub target_user_id: i32,
}

#[derive(Debug, Deserialize)]
pub struct UpdateReceiptRequest {
    pub state: String, // 'delivered' or 'read'
}

#[derive(Debug, Deserialize)]
pub struct ThreadListQuery {
    pub mode: Option<String>, // 'personal' or 'admin'
}

#[derive(Debug, Deserialize)]
pub struct MessageListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct RelatedTeacher {
    pub user_id: i32,
    pub name: String,
}

// ============================================================================
// Access Control Functions
// ============================================================================

/// Check if a user can message another user based on visibility circle rules
pub async fn can_message_user(
    pool: &PgPool,
    initiator_id: i32,
    target_id: i32,
) -> Result<bool, sqlx::Error> {
    // Check if they have a relationship
    // 1. Parent-student relationship
    let parent_student = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1
            FROM parent_student_relations psr
            JOIN parents p ON p.user_id = psr.parent_user_id
            WHERE p.status = 'active'
              AND ((psr.parent_user_id = $1 AND psr.student_user_id = $2)
                   OR (psr.parent_user_id = $2 AND psr.student_user_id = $1))
        )",
    )
    .bind(initiator_id)
    .bind(target_id)
    .fetch_one(pool)
    .await?;

    if parent_student {
        return Ok(true);
    }

    // 2. Teacher-student relationship
    let teacher_student = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM teacher_student_relations
            WHERE (teacher_user_id = $1 AND student_user_id = $2)
               OR (teacher_user_id = $2 AND student_user_id = $1)
        )",
    )
    .bind(initiator_id)
    .bind(target_id)
    .fetch_one(pool)
    .await?;

    if teacher_student {
        return Ok(true);
    }

    // 3. Both are parents of the same children
    let same_child_parents = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1
            FROM parent_student_relations psr1
            JOIN parent_student_relations psr2 ON psr1.student_user_id = psr2.student_user_id
            JOIN parents p1 ON p1.user_id = psr1.parent_user_id
            JOIN parents p2 ON p2.user_id = psr2.parent_user_id
            WHERE psr1.parent_user_id = $1
              AND psr2.parent_user_id = $2
              AND p1.status = 'active'
              AND p2.status = 'active'
        )",
    )
    .bind(initiator_id)
    .bind(target_id)
    .fetch_one(pool)
    .await?;

    if same_child_parents {
        return Ok(true);
    }

    // 4. Parent of a student whose teacher is the target (visibility circle)
    let parent_of_student_of_teacher = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1
            FROM parent_student_relations psr
            JOIN parents p ON p.user_id = psr.parent_user_id
            JOIN teacher_student_relations tsr ON psr.student_user_id = tsr.student_user_id
            WHERE psr.parent_user_id = $1
              AND tsr.teacher_user_id = $2
              AND p.status = 'active'
        )",
    )
    .bind(initiator_id)
    .bind(target_id)
    .fetch_one(pool)
    .await?;

    if parent_of_student_of_teacher {
        return Ok(true);
    }

    // 5. Reverse: teacher of a student whose parent is the target
    let teacher_of_student_of_parent = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1
            FROM teacher_student_relations tsr
            JOIN parent_student_relations psr ON tsr.student_user_id = psr.student_user_id
            JOIN parents p ON p.user_id = psr.parent_user_id
            WHERE tsr.teacher_user_id = $1
              AND psr.parent_user_id = $2
              AND p.status = 'active'
        )",
    )
    .bind(initiator_id)
    .bind(target_id)
    .fetch_one(pool)
    .await?;

    Ok(teacher_of_student_of_parent)
}

async fn fetch_available_user_ids(
    pool: &PgPool,
    user_id: i32,
    roles: &[String],
) -> Result<HashSet<i32>, sqlx::Error> {
    let mut user_ids: HashSet<i32> = HashSet::new();

    if roles.iter().any(|role| role == "admin") {
        let ids = sqlx::query_scalar::<_, i32>("SELECT id FROM users WHERE id <> $1")
            .bind(user_id)
            .fetch_all(pool)
            .await?;
        user_ids.extend(ids);
    } else if roles.iter().any(|role| role == "teacher") {
        let student_ids = sqlx::query_scalar::<_, i32>(
            "SELECT student_user_id FROM teacher_student_relations WHERE teacher_user_id = $1",
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;

        user_ids.extend(student_ids.iter().copied());

        if !student_ids.is_empty() {
            let parent_ids = sqlx::query_scalar::<_, i32>(
                "SELECT DISTINCT psr.parent_user_id
                                 FROM parent_student_relations psr
                                 JOIN parents p ON p.user_id = psr.parent_user_id
                                 WHERE psr.student_user_id = ANY($1)
                                     AND p.status = 'active'",
            )
            .bind(&student_ids)
            .fetch_all(pool)
            .await?;
            user_ids.extend(parent_ids);
        }

        let teacher_ids =
            sqlx::query_scalar::<_, i32>("SELECT user_id FROM teachers WHERE user_id <> $1")
                .bind(user_id)
                .fetch_all(pool)
                .await?;
        user_ids.extend(teacher_ids);

        let admin_ids = sqlx::query_scalar::<_, i32>(
            "SELECT DISTINCT ur.user_id
             FROM user_roles ur
             JOIN roles r ON ur.role_id = r.id
             WHERE r.name = 'admin'",
        )
        .fetch_all(pool)
        .await?;
        user_ids.extend(admin_ids);
    } else if roles.iter().any(|role| role == "student") {
        let parent_ids = sqlx::query_scalar::<_, i32>(
            "SELECT psr.parent_user_id
                         FROM parent_student_relations psr
                         JOIN parents p ON p.user_id = psr.parent_user_id
                         WHERE psr.student_user_id = $1
                             AND p.status = 'active'",
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;
        user_ids.extend(parent_ids);

        let teacher_ids = sqlx::query_scalar::<_, i32>(
            "SELECT teacher_user_id
             FROM teacher_student_relations
             WHERE student_user_id = $1",
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;
        user_ids.extend(teacher_ids.iter().copied());

        if !teacher_ids.is_empty() {
            let related_student_ids = sqlx::query_scalar::<_, i32>(
                "SELECT DISTINCT student_user_id
                 FROM teacher_student_relations
                 WHERE teacher_user_id = ANY($1)",
            )
            .bind(&teacher_ids)
            .fetch_all(pool)
            .await?;
            user_ids.extend(related_student_ids.iter().copied());

            if !related_student_ids.is_empty() {
                let related_parent_ids = sqlx::query_scalar::<_, i32>(
                    "SELECT DISTINCT psr.parent_user_id
                                         FROM parent_student_relations psr
                                         JOIN parents p ON p.user_id = psr.parent_user_id
                                         WHERE psr.student_user_id = ANY($1)
                                             AND p.status = 'active'",
                )
                .bind(&related_student_ids)
                .fetch_all(pool)
                .await?;
                user_ids.extend(related_parent_ids);
            }
        }
    } else if roles.iter().any(|role| role == "parent") {
        let child_ids = sqlx::query_scalar::<_, i32>(
            "SELECT psr.student_user_id
                         FROM parent_student_relations psr
                         JOIN parents p ON p.user_id = psr.parent_user_id
                         WHERE psr.parent_user_id = $1
                             AND p.status = 'active'",
        )
        .bind(user_id)
        .fetch_all(pool)
        .await?;
        user_ids.extend(child_ids.iter().copied());

        if !child_ids.is_empty() {
            let teacher_ids = sqlx::query_scalar::<_, i32>(
                "SELECT DISTINCT teacher_user_id
                 FROM teacher_student_relations
                 WHERE student_user_id = ANY($1)",
            )
            .bind(&child_ids)
            .fetch_all(pool)
            .await?;
            user_ids.extend(teacher_ids.iter().copied());

            if !teacher_ids.is_empty() {
                let related_student_ids = sqlx::query_scalar::<_, i32>(
                    "SELECT DISTINCT student_user_id
                     FROM teacher_student_relations
                     WHERE teacher_user_id = ANY($1)",
                )
                .bind(&teacher_ids)
                .fetch_all(pool)
                .await?;
                user_ids.extend(related_student_ids.iter().copied());

                if !related_student_ids.is_empty() {
                    let related_parent_ids = sqlx::query_scalar::<_, i32>(
                        "SELECT DISTINCT psr.parent_user_id
                                                 FROM parent_student_relations psr
                                                 JOIN parents p ON p.user_id = psr.parent_user_id
                                                 WHERE psr.student_user_id = ANY($1)
                                                     AND p.status = 'active'",
                    )
                    .bind(&related_student_ids)
                    .fetch_all(pool)
                    .await?;
                    user_ids.extend(related_parent_ids);
                }
            }
        }
    }

    user_ids.remove(&user_id);
    Ok(user_ids)
}

/// Get all teachers related to a user (for toolbar shortcuts)
pub async fn get_related_teachers(
    pool: &PgPool,
    user_id: i32,
) -> Result<Vec<RelatedTeacher>, sqlx::Error> {
    // Check if user is a student
    let student_teachers = sqlx::query_as::<_, (i32, String)>(
        "SELECT DISTINCT t.user_id, u.full_name
         FROM teacher_student_relations tsr
         JOIN teachers t ON tsr.teacher_user_id = t.user_id
         JOIN users u ON t.user_id = u.id
         WHERE tsr.student_user_id = $1
         AND t.status = 'active'
         ORDER BY u.full_name",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    if !student_teachers.is_empty() {
        return Ok(student_teachers
            .into_iter()
            .map(|(id, name)| RelatedTeacher { user_id: id, name })
            .collect());
    }

    // If not a student, check if user is a parent with children
    let parent_children_teachers = sqlx::query_as::<_, (i32, String)>(
        "SELECT DISTINCT t.user_id, u.full_name
         FROM parent_student_relations psr
            JOIN parents p ON p.user_id = psr.parent_user_id
         JOIN teacher_student_relations tsr ON psr.student_user_id = tsr.student_user_id
         JOIN teachers t ON tsr.teacher_user_id = t.user_id
         JOIN users u ON t.user_id = u.id
         WHERE psr.parent_user_id = $1
            AND p.status = 'active'
         AND t.status = 'active'
         ORDER BY u.full_name",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    Ok(parent_children_teachers
        .into_iter()
        .map(|(id, name)| RelatedTeacher { user_id: id, name })
        .collect())
}

/// Check if a user can view a specific thread
async fn can_view_thread(pool: &PgPool, user_id: i32, thread_id: i32) -> Result<bool, sqlx::Error> {
    // Get thread info
    let thread = sqlx::query_as::<_, ChatThread>(
        "SELECT id, participant_a_id, participant_b_id, is_admin_chat, created_at, updated_at
         FROM chat_threads WHERE id = $1",
    )
    .bind(thread_id)
    .fetch_optional(pool)
    .await?;

    let thread = match thread {
        Some(t) => t,
        None => return Ok(false),
    };

    // Admin chats: only admins can view (except their own)
    if thread.is_admin_chat {
        let is_admin = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1 FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = $1 AND r.name = 'admin'
            )",
        )
        .bind(user_id)
        .fetch_one(pool)
        .await?;

        // Admin can view all admin chats, non-admin can view their own initiation
        return Ok(is_admin || user_id == thread.participant_a_id);
    }

    // Peer chats: user must be one of the participants
    Ok(user_id == thread.participant_a_id || Some(user_id) == thread.participant_b_id)
}

// ============================================================================
// Route Handlers
// ============================================================================

/// Get thread list (personal or admin mode)
async fn list_threads(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    query: web::Query<ThreadListQuery>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let mode = query.mode.as_deref().unwrap_or("personal");

    let threads = if mode == "admin" {
        // Only admins can view admin chat mode
        let is_admin = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1 FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = $1 AND r.name = 'admin'
            )",
        )
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

        if !is_admin {
            return Ok(HttpResponse::Forbidden().json(json!({
                "error": "Only admins can view admin chat mode"
            })));
        }

        // Get all admin chat threads (incoming messages to admin)
        sqlx::query_as::<_, ChatThread>(
            "SELECT id, participant_a_id, participant_b_id, is_admin_chat, created_at, updated_at
             FROM chat_threads
             WHERE is_admin_chat = true
             ORDER BY updated_at DESC",
        )
        .fetch_all(&app_state.db)
        .await
    } else {
        // Personal mode: get peer threads for this user
        sqlx::query_as::<_, ChatThread>(
            "SELECT id, participant_a_id, participant_b_id, is_admin_chat, created_at, updated_at
             FROM chat_threads
                 WHERE (
                         (is_admin_chat = false AND (participant_a_id = $1 OR participant_b_id = $1))
                     OR (is_admin_chat = true AND participant_a_id = $1)
                 )
             ORDER BY updated_at DESC",
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
    }
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    // Enrich with peer info and last message
    let mut responses = Vec::new();
    for thread in threads {
        let peer_id = if thread.participant_a_id == user_id {
            thread.participant_b_id
        } else if mode == "admin" {
            Some(thread.participant_a_id)
        } else {
            Some(thread.participant_a_id)
        };

        let peer_name = if let Some(pid) = peer_id {
            sqlx::query_scalar::<_, Option<String>>(
                "SELECT COALESCE(full_name, username)
                 FROM users
                 WHERE id = $1",
            )
            .bind(pid)
            .fetch_one(&app_state.db)
            .await
            .ok()
            .flatten()
        } else {
            Some("Administration".to_string())
        };

        let last_message = sqlx::query_as::<_, ChatMessage>(
            "SELECT id, thread_id, sender_id, body, created_at, updated_at
             FROM chat_messages
             WHERE thread_id = $1
             ORDER BY created_at DESC
             LIMIT 1",
        )
        .bind(thread.id)
        .fetch_optional(&app_state.db)
        .await
        .ok()
        .flatten();

        let last_message_response = if let Some(msg) = last_message {
            let sender_name = sqlx::query_scalar::<_, Option<String>>(
                "SELECT COALESCE(full_name, username)
                 FROM users
                 WHERE id = $1",
            )
            .bind(msg.sender_id)
            .fetch_one(&app_state.db)
            .await
            .ok()
            .flatten()
            .unwrap_or_default();

            let receipts = sqlx::query_as::<_, MessageReceipt>(
                "SELECT id, message_id, recipient_id, state, updated_at
                 FROM message_receipts
                 WHERE message_id = $1",
            )
            .bind(msg.id)
            .fetch_all(&app_state.db)
            .await
            .ok()
            .unwrap_or_default();

            let attachments = load_attachments_for_messages(&app_state.db, &[msg.id])
                .await
                .ok()
                .and_then(|map| map.get(&msg.id).cloned())
                .unwrap_or_default();

            Some(ChatMessageResponse {
                id: msg.id,
                sender_id: msg.sender_id,
                sender_name,
                body: msg.body,
                created_at: msg.created_at,
                updated_at: msg.updated_at,
                receipts: receipts
                    .into_iter()
                    .map(|r| ReceiptResponse {
                        recipient_id: r.recipient_id,
                        state: r.state,
                        updated_at: r.updated_at,
                    })
                    .collect(),
                attachments,
            })
        } else {
            None
        };

        let unread_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*)
             FROM message_receipts mr
             JOIN chat_messages cm ON mr.message_id = cm.id
             WHERE cm.thread_id = $1
             AND mr.recipient_id = $2
               AND mr.state <> 'read'::chat_message_state",
        )
        .bind(thread.id)
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .ok()
        .unwrap_or(0) as i32;

        responses.push(ChatThreadResponse {
            id: thread.id,
            participant_a_id: thread.participant_a_id,
            participant_b_id: thread.participant_b_id,
            peer_user_id: peer_id,
            peer_name,
            is_admin_chat: thread.is_admin_chat,
            last_message: last_message_response,
            updated_at: thread.updated_at,
            unread_count,
        });
    }

    Ok(HttpResponse::Ok().json(responses))
}

/// Get message history for a thread with pagination
async fn get_thread_messages(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    thread_id: web::Path<i32>,
    query: web::Query<MessageListQuery>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let thread_id = thread_id.into_inner();

    // Check access
    let can_view = can_view_thread(&app_state.db, user_id, thread_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    if !can_view {
        return Ok(HttpResponse::Forbidden().json(json!({
            "error": "Cannot access this thread"
        })));
    }

    let limit = query.limit.unwrap_or(50);
    let offset = query.offset.unwrap_or(0);

    let messages = sqlx::query_as::<_, ChatMessage>(
        "SELECT id, thread_id, sender_id, body, created_at, updated_at
         FROM chat_messages
         WHERE thread_id = $1
         ORDER BY created_at DESC
         LIMIT $2 OFFSET $3",
    )
    .bind(thread_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    let message_ids: Vec<i32> = messages.iter().map(|msg| msg.id).collect();
    let attachments_map = load_attachments_for_messages(&app_state.db, &message_ids)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    let mut responses = Vec::new();
    for msg in messages {
        let sender_name = sqlx::query_scalar::<_, Option<String>>(
            "SELECT COALESCE(full_name, username)
             FROM users
             WHERE id = $1",
        )
        .bind(msg.sender_id)
        .fetch_one(&app_state.db)
        .await
        .ok()
        .flatten()
        .unwrap_or_default();

        let receipts = sqlx::query_as::<_, MessageReceipt>(
            "SELECT id, message_id, recipient_id, state, updated_at
             FROM message_receipts
             WHERE message_id = $1",
        )
        .bind(msg.id)
        .fetch_all(&app_state.db)
        .await
        .ok()
        .unwrap_or_default();

        responses.push(ChatMessageResponse {
            id: msg.id,
            sender_id: msg.sender_id,
            sender_name,
            body: msg.body,
            created_at: msg.created_at,
            updated_at: msg.updated_at,
            receipts: receipts
                .into_iter()
                .map(|r| ReceiptResponse {
                    recipient_id: r.recipient_id,
                    state: r.state,
                    updated_at: r.updated_at,
                })
                .collect(),
            attachments: attachments_map.get(&msg.id).cloned().unwrap_or_default(),
        });
    }

    Ok(HttpResponse::Ok().json(responses))
}

/// Start a new peer-to-peer chat thread
async fn start_thread(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    payload: web::Json<StartThreadRequest>,
) -> Result<HttpResponse> {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(_response) => {
            return Err(actix_web::error::ErrorUnauthorized(
                "Invalid or missing token",
            ))
        }
    };
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let target_id = payload.target_user_id;

    let available_user_ids = fetch_available_user_ids(&app_state.db, user_id, &claims.roles)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    if !available_user_ids.contains(&target_id) {
        return Ok(HttpResponse::Forbidden().json(json!({
            "error": "Cannot message this user"
        })));
    }

    // Check if thread already exists
    let existing_thread = sqlx::query_scalar::<_, Option<i32>>(
        "SELECT id FROM chat_threads
         WHERE is_admin_chat = false
         AND ((participant_a_id = $1 AND participant_b_id = $2)
              OR (participant_a_id = $2 AND participant_b_id = $1))",
    )
    .bind(user_id)
    .bind(target_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    if let Some(thread_id) = existing_thread {
        return Ok(HttpResponse::Ok().json(json!({"thread_id": thread_id})));
    }

    // Create new thread
    let thread_id = sqlx::query_scalar::<_, i32>(
        "INSERT INTO chat_threads (participant_a_id, participant_b_id, is_admin_chat)
         VALUES ($1, $2, false)
         RETURNING id",
    )
    .bind(user_id)
    .bind(target_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    Ok(HttpResponse::Created().json(json!({"thread_id": thread_id})))
}

/// Send a message to a thread
async fn send_message(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    thread_id: web::Path<i32>,
    payload: web::Json<CreateMessageRequest>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let thread_id = thread_id.into_inner();

    // Check access
    let can_view = can_view_thread(&app_state.db, user_id, thread_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    if !can_view {
        return Ok(HttpResponse::Forbidden().json(json!({
            "error": "Cannot access this thread"
        })));
    }

    // Get thread details to determine recipient(s)
    let thread = sqlx::query_as::<_, ChatThread>(
        "SELECT id, participant_a_id, participant_b_id, is_admin_chat, created_at, updated_at
         FROM chat_threads WHERE id = $1",
    )
    .bind(thread_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    // Determine recipient(s)
    let recipients = if thread.is_admin_chat {
        let is_sender_admin = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1 FROM user_roles ur
                JOIN roles r ON ur.role_id = r.id
                WHERE ur.user_id = $1 AND r.name = 'admin'
            )",
        )
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

        if is_sender_admin {
            vec![thread.participant_a_id]
        } else {
            // For admin chat from users, all admins are recipients
            sqlx::query_scalar::<_, i32>(
                "SELECT DISTINCT ur.user_id
                 FROM user_roles ur
                 JOIN roles r ON ur.role_id = r.id
                 WHERE r.name = 'admin'
                 AND ur.user_id != $1",
            )
            .bind(user_id)
            .fetch_all(&app_state.db)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?
        }
    } else {
        // For peer chat, the other participant is the recipient
        let recipient = if user_id == thread.participant_a_id {
            thread.participant_b_id
        } else {
            Some(thread.participant_a_id)
        };
        recipient.into_iter().collect()
    };

    // Insert message
    let (message_id, created_at, updated_at) =
        sqlx::query_as::<_, (i32, DateTime<Utc>, DateTime<Utc>)>(
            "INSERT INTO chat_messages (thread_id, sender_id, body)
         VALUES ($1, $2, $3)
         RETURNING id, created_at, updated_at",
        )
        .bind(thread_id)
        .bind(user_id)
        .bind(&payload.body)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    let attachments = if let Some(items) = payload.attachments.as_deref() {
        match store_message_attachments(&app_state.db, user_id, message_id, items).await {
            Ok(items) => items,
            Err(response) => return Ok(response),
        }
    } else {
        Vec::new()
    };

    // Insert receipts for each recipient
    for recipient_id in &recipients {
        sqlx::query(
            "INSERT INTO message_receipts (message_id, recipient_id, state)
             VALUES ($1, $2, 'sent')",
        )
        .bind(message_id)
        .bind(recipient_id)
        .execute(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;
    }

    // Update thread updated_at
    sqlx::query("UPDATE chat_threads SET updated_at = NOW() WHERE id = $1")
        .bind(thread_id)
        .execute(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    // Broadcast message via WebSocket
    let sender_name = fetch_user_display_name(&app_state.db, user_id).await;
    let preview = chat_message_preview(&payload.body);
    let message_data = serde_json::json!({
        "message_id": message_id,
        "thread_id": thread_id,
        "sender_id": user_id,
        "sender_name": sender_name,
        "body": payload.body.clone(),
        "attachments": attachments,
        "created_at": created_at.to_rfc3339(),
        "updated_at": updated_at.to_rfc3339(),
    });

    let ws_message = websockets::WsMessage {
        msg_type: "chat_message".to_string(),
        user_id: Some(user_id),
        thread_id: Some(thread_id),
        post_id: None,
        data: message_data,
    };

    app_state
        .ws_server
        .broadcast_to_thread(thread_id, ws_message)
        .await;

    let notification_body = build_chat_notification(&sender_name, &preview, thread_id, user_id);
    for recipient_id in &recipients {
        let notification_id = sqlx::query_scalar::<_, i32>(
            "INSERT INTO notifications (user_id, type, title, body, priority)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id",
        )
        .bind(recipient_id)
        .bind(&notification_body.body_type)
        .bind(&notification_body.title)
        .bind(serde_json::to_value(&notification_body).unwrap_or_default())
        .bind("normal")
        .fetch_optional(&app_state.db)
        .await
        .unwrap_or(None);

        if let Some(notification_id) = notification_id {
            debug!(
                "[CHAT] Sending push to user {} for thread {}",
                recipient_id, thread_id
            );
            push::send_notification_to_user(
                &app_state.db,
                *recipient_id,
                &notification_body,
                Some(notification_id),
            )
            .await;
        }
    }

    Ok(HttpResponse::Created().json(json!({
        "message_id": message_id,
        "recipients": recipients,
        "attachments": attachments
    })))
}

/// Send a message to admin (non-admin users)
async fn send_admin_message(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    payload: web::Json<CreateMessageRequest>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    // Find or create admin chat thread for this user
    let existing_thread = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM chat_threads
         WHERE is_admin_chat = true AND participant_a_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    let thread_id = match existing_thread {
        Some(id) => id,
        None => sqlx::query_scalar::<_, i32>(
            "INSERT INTO chat_threads (participant_a_id, is_admin_chat)
                 VALUES ($1, true)
                 RETURNING id",
        )
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?,
    };

    // Insert message
    let (message_id, created_at, updated_at) =
        sqlx::query_as::<_, (i32, DateTime<Utc>, DateTime<Utc>)>(
            "INSERT INTO chat_messages (thread_id, sender_id, body)
         VALUES ($1, $2, $3)
         RETURNING id, created_at, updated_at",
        )
        .bind(thread_id)
        .bind(user_id)
        .bind(&payload.body)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    let attachments = if let Some(items) = payload.attachments.as_deref() {
        match store_message_attachments(&app_state.db, user_id, message_id, items).await {
            Ok(items) => items,
            Err(response) => return Ok(response),
        }
    } else {
        Vec::new()
    };

    // Get all admin users as recipients
    let admin_recipients = sqlx::query_scalar::<_, i32>(
        "SELECT DISTINCT ur.user_id
         FROM user_roles ur
         JOIN roles r ON ur.role_id = r.id
         WHERE r.name = 'admin'",
    )
    .fetch_all(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    // Insert receipts for each admin
    for admin_id in &admin_recipients {
        sqlx::query(
            "INSERT INTO message_receipts (message_id, recipient_id, state)
             VALUES ($1, $2, 'sent')",
        )
        .bind(message_id)
        .bind(admin_id)
        .execute(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;
    }

    // Update thread updated_at
    sqlx::query("UPDATE chat_threads SET updated_at = NOW() WHERE id = $1")
        .bind(thread_id)
        .execute(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    // Broadcast message via WebSocket
    let sender_name = fetch_user_display_name(&app_state.db, user_id).await;
    let preview = chat_message_preview(&payload.body);
    let message_data = serde_json::json!({
        "message_id": message_id,
        "thread_id": thread_id,
        "sender_id": user_id,
        "sender_name": sender_name,
        "body": payload.body.clone(),
        "attachments": attachments,
        "created_at": created_at.to_rfc3339(),
        "updated_at": updated_at.to_rfc3339(),
    });

    let ws_message = websockets::WsMessage {
        msg_type: "chat_message".to_string(),
        user_id: Some(user_id),
        thread_id: Some(thread_id),
        post_id: None,
        data: message_data,
    };

    app_state
        .ws_server
        .broadcast_to_thread(thread_id, ws_message)
        .await;

    let notification_body = build_chat_notification(&sender_name, &preview, thread_id, user_id);
    for admin_id in &admin_recipients {
        let notification_id = sqlx::query_scalar::<_, i32>(
            "INSERT INTO notifications (user_id, type, title, body, priority)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id",
        )
        .bind(admin_id)
        .bind(&notification_body.body_type)
        .bind(&notification_body.title)
        .bind(serde_json::to_value(&notification_body).unwrap_or_default())
        .bind("normal")
        .fetch_optional(&app_state.db)
        .await
        .unwrap_or(None);

        if let Some(notification_id) = notification_id {
            debug!(
                "[CHAT] Sending push to admin {} for thread {}",
                admin_id, thread_id
            );
            push::send_notification_to_user(
                &app_state.db,
                *admin_id,
                &notification_body,
                Some(notification_id),
            )
            .await;
        }
    }

    Ok(HttpResponse::Created().json(json!({
        "message_id": message_id,
        "thread_id": thread_id,
        "attachments": attachments,
        "created_at": created_at,
        "updated_at": updated_at
    })))
}

/// Update message delivery receipt state
async fn update_receipt(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    message_id: web::Path<i32>,
    payload: web::Json<UpdateReceiptRequest>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let message_id = message_id.into_inner();

    if payload.state != "delivered" && payload.state != "read" {
        warn!(
            "receipt update invalid state: message_id={}, recipient_id={}, state={}",
            message_id, user_id, payload.state
        );
        return Ok(HttpResponse::BadRequest().json(json!({
            "error": "Invalid receipt state"
        })));
    }

    // Get thread_id for broadcasting
    let thread_id =
        sqlx::query_scalar::<_, i32>("SELECT thread_id FROM chat_messages WHERE id = $1")
            .bind(message_id)
            .fetch_optional(&app_state.db)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?
            .ok_or_else(|| actix_web::error::ErrorNotFound("Message not found"))?;

    // Update receipt
    let rows = sqlx::query(
        "UPDATE message_receipts
            SET state = $1::chat_message_state, updated_at = NOW()
         WHERE message_id = $2 AND recipient_id = $3",
    )
    .bind(&payload.state)
    .bind(message_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    debug!(
        "receipt update: message_id={}, recipient_id={}, state={}, rows_affected={}",
        message_id,
        user_id,
        payload.state,
        rows.rows_affected()
    );

    if rows.rows_affected() == 0 {
        warn!(
            "receipt update not found: message_id={}, recipient_id={} (no receipt row)",
            message_id, user_id
        );
        return Ok(HttpResponse::NotFound().json(json!({
            "error": "Receipt not found"
        })));
    }

    // Broadcast receipt update via WebSocket
    let ws_message = websockets::WsMessage {
        msg_type: "receipt".to_string(),
        user_id: Some(user_id),
        thread_id: Some(thread_id),
        post_id: None,
        data: serde_json::json!({
            "message_id": message_id,
            "recipient_id": user_id,
            "state": payload.state,
        }),
    };

    app_state
        .ws_server
        .broadcast_to_thread(thread_id, ws_message)
        .await;

    Ok(HttpResponse::Ok().json(json!({"state": payload.state})))
}

/// Update a chat message body (author only)
async fn update_message(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    message_id: web::Path<i32>,
    payload: web::Json<UpdateMessageRequest>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let message_id = message_id.into_inner();

    let message = sqlx::query_as::<_, ChatMessage>(
        "SELECT id, thread_id, sender_id, body, created_at, updated_at
         FROM chat_messages
         WHERE id = $1",
    )
    .bind(message_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Message not found"))?;

    if message.sender_id != user_id {
        return Ok(HttpResponse::Forbidden().json(json!({
            "error": "Not allowed"
        })));
    }

    let updated_message = sqlx::query_as::<_, ChatMessage>(
        "UPDATE chat_messages
         SET body = $1
         WHERE id = $2
         RETURNING id, thread_id, sender_id, body, created_at, updated_at",
    )
    .bind(&payload.body)
    .bind(message_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    let sender_name = fetch_user_display_name(&app_state.db, user_id).await;
    let receipts = sqlx::query_as::<_, MessageReceipt>(
        "SELECT id, message_id, recipient_id, state, updated_at
         FROM message_receipts
         WHERE message_id = $1",
    )
    .bind(updated_message.id)
    .fetch_all(&app_state.db)
    .await
    .ok()
    .unwrap_or_default();

    let attachments = load_attachments_for_messages(&app_state.db, &[updated_message.id])
        .await
        .ok()
        .and_then(|map| map.get(&updated_message.id).cloned())
        .unwrap_or_default();

    let response = ChatMessageResponse {
        id: updated_message.id,
        sender_id: updated_message.sender_id,
        sender_name: sender_name.clone(),
        body: updated_message.body,
        created_at: updated_message.created_at,
        updated_at: updated_message.updated_at,
        receipts: receipts
            .into_iter()
            .map(|r| ReceiptResponse {
                recipient_id: r.recipient_id,
                state: r.state,
                updated_at: r.updated_at,
            })
            .collect(),
        attachments: attachments.clone(),
    };

    let ws_message = websockets::WsMessage {
        msg_type: "chat_message_updated".to_string(),
        user_id: Some(user_id),
        thread_id: Some(updated_message.thread_id),
        post_id: None,
        data: serde_json::json!({
            "message_id": response.id,
            "thread_id": updated_message.thread_id,
            "sender_id": response.sender_id,
            "sender_name": response.sender_name,
            "body": response.body,
            "attachments": response.attachments,
            "created_at": response.created_at.to_rfc3339(),
            "updated_at": response.updated_at.to_rfc3339(),
        }),
    };

    app_state
        .ws_server
        .broadcast_to_thread(updated_message.thread_id, ws_message)
        .await;

    Ok(HttpResponse::Ok().json(response))
}

/// Delete a chat message (author only)
async fn delete_message(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    message_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let message_id = message_id.into_inner();

    let message = sqlx::query_as::<_, ChatMessage>(
        "SELECT id, thread_id, sender_id, body, created_at, updated_at
         FROM chat_messages
         WHERE id = $1",
    )
    .bind(message_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Message not found"))?;

    if message.sender_id != user_id {
        return Ok(HttpResponse::Forbidden().json(json!({
            "error": "Not allowed"
        })));
    }

    let mut tx = app_state.db.begin().await.map_err(|e| {
        error!("Failed to start transaction: {}", e);
        actix_web::error::ErrorInternalServerError("Database error")
    })?;

    sqlx::query("DELETE FROM message_receipts WHERE message_id = $1")
        .bind(message_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            error!("Failed to delete message receipts: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to delete message")
        })?;

    sqlx::query("DELETE FROM chat_message_attachments WHERE message_id = $1")
        .bind(message_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            error!("Failed to delete message attachments: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to delete message")
        })?;

    sqlx::query("DELETE FROM chat_messages WHERE id = $1")
        .bind(message_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            error!("Failed to delete message: {}", e);
            actix_web::error::ErrorInternalServerError("Failed to delete message")
        })?;

    sqlx::query(
        "UPDATE chat_threads
         SET updated_at = COALESCE((
             SELECT created_at FROM chat_messages
             WHERE thread_id = $1
             ORDER BY created_at DESC
             LIMIT 1
         ), NOW())
         WHERE id = $1",
    )
    .bind(message.thread_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        error!("Failed to update thread timestamp: {}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete message")
    })?;

    tx.commit().await.map_err(|e| {
        error!("Failed to commit delete message transaction: {}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete message")
    })?;

    let ws_message = websockets::WsMessage {
        msg_type: "chat_message_deleted".to_string(),
        user_id: Some(user_id),
        thread_id: Some(message.thread_id),
        post_id: None,
        data: serde_json::json!({
            "message_id": message_id,
        }),
    };

    app_state
        .ws_server
        .broadcast_to_thread(message.thread_id, ws_message)
        .await;

    Ok(HttpResponse::Ok().json(json!({
        "message_id": message_id,
        "thread_id": message.thread_id,
    })))
}

/// Get related teachers for current user (for toolbar)
async fn get_related_teachers_handler(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> Result<HttpResponse> {
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let teachers = get_related_teachers(&app_state.db, user_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    Ok(HttpResponse::Ok().json(teachers))
}

/// List available chat users based on role relationships
async fn list_available_chat_users(
    req: HttpRequest,
    app_state: web::Data<AppState>,
) -> Result<HttpResponse> {
    let claims = match verify_token(&req, &app_state) {
        Ok(claims) => claims,
        Err(_response) => {
            return Err(actix_web::error::ErrorUnauthorized(
                "Invalid or missing token",
            ))
        }
    };
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let user_ids = fetch_available_user_ids(&app_state.db, user_id, &claims.roles)
        .await
        .unwrap_or_default();
    if user_ids.is_empty() {
        return Ok(HttpResponse::Ok().json(Vec::<AvailableChatUser>::new()));
    }

    let ids: Vec<i32> = user_ids.into_iter().collect();
    let users = sqlx::query_as::<_, AvailableChatUser>(
        "SELECT u.id as user_id,
                u.username,
                COALESCE(u.full_name, u.username) as full_name,
                u.profile_image
         FROM users u
         WHERE u.id = ANY($1)
         ORDER BY full_name",
    )
    .bind(&ids)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default();

    Ok(HttpResponse::Ok().json(users))
}

// ============================================================================
// Route Configuration
// ============================================================================

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/chat")
            .route("/threads", web::get().to(list_threads))
            .route("/threads", web::post().to(start_thread))
            .route(
                "/threads/{thread_id}/messages",
                web::get().to(get_thread_messages),
            )
            .route(
                "/threads/{thread_id}/messages",
                web::post().to(send_message),
            )
            .route("/messages/{message_id}", web::patch().to(update_message))
            .route("/messages/{message_id}", web::delete().to(delete_message))
            .route(
                "/messages/{message_id}/receipt",
                web::patch().to(update_receipt),
            )
            .route("/admin/message", web::post().to(send_admin_message))
            .route(
                "/related-teachers",
                web::get().to(get_related_teachers_handler),
            )
            .route("/available-users", web::get().to(list_available_chat_users)),
    );
}
