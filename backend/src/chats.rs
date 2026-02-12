use actix_web::{web, HttpRequest, HttpResponse, Result};
use chrono::{DateTime, Utc};
use log::{debug, error, warn};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{FromRow, PgPool};

use crate::users::verify_token;
use crate::websockets;
use crate::AppState;

// ============================================================================
// Helper functions
// ============================================================================

async fn extract_user_id_from_token(req: &HttpRequest, app_state: &AppState) -> Result<i32> {
    let claims = match verify_token(req, app_state) {
        Ok(claims) => claims,
        Err(_response) => return Err(actix_web::error::ErrorUnauthorized("Invalid or missing token")),
    };

    let user_id = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
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
        "SELECT COALESCE(
            (SELECT full_name FROM students WHERE user_id = $1),
            (SELECT full_name FROM parents WHERE user_id = $1),
            (SELECT full_name FROM teachers WHERE user_id = $1),
            (SELECT username FROM users WHERE id = $1)
        )"
    )
    .bind(user_id)
    .fetch_optional(db)
    .await
    .unwrap_or(None)
    .unwrap_or_else(|| "Unknown".to_string())
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
    pub receipts: Vec<ReceiptResponse>,
}

#[derive(Debug, Serialize, Clone)]
pub struct ReceiptResponse {
    pub recipient_id: i32,
    pub state: String,
    pub updated_at: DateTime<Utc>,
}

// Request DTOs
#[derive(Debug, Deserialize)]
pub struct CreateMessageRequest {
    pub body: serde_json::Value, // Quill JSON
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
            SELECT 1 FROM parent_student_relations
            WHERE (parent_user_id = $1 AND student_user_id = $2)
               OR (parent_user_id = $2 AND student_user_id = $1)
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
            WHERE psr1.parent_user_id = $1 AND psr2.parent_user_id = $2
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
            JOIN teacher_student_relations tsr ON psr.student_user_id = tsr.student_user_id
            WHERE psr.parent_user_id = $1 AND tsr.teacher_user_id = $2
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
            WHERE tsr.teacher_user_id = $1 AND psr.parent_user_id = $2
        )",
    )
    .bind(initiator_id)
    .bind(target_id)
    .fetch_one(pool)
    .await?;

    Ok(teacher_of_student_of_parent)
}

/// Get all teachers related to a user (for toolbar shortcuts)
pub async fn get_related_teachers(
    pool: &PgPool,
    user_id: i32,
) -> Result<Vec<RelatedTeacher>, sqlx::Error> {
    // Check if user is a student
    let student_teachers = sqlx::query_as::<_, (i32, String)>(
        "SELECT DISTINCT t.user_id, t.full_name
         FROM teacher_student_relations tsr
         JOIN teachers t ON tsr.teacher_user_id = t.user_id
         WHERE tsr.student_user_id = $1
         AND t.status = 'active'
         ORDER BY t.full_name",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    if !student_teachers.is_empty() {
        return Ok(student_teachers
            .into_iter()
            .map(|(id, name)| RelatedTeacher {
                user_id: id,
                name,
            })
            .collect());
    }

    // If not a student, check if user is a parent with children
    let parent_children_teachers = sqlx::query_as::<_, (i32, String)>(
        "SELECT DISTINCT t.user_id, t.full_name
         FROM parent_student_relations psr
         JOIN teacher_student_relations tsr ON psr.student_user_id = tsr.student_user_id
         JOIN teachers t ON tsr.teacher_user_id = t.user_id
         WHERE psr.parent_user_id = $1
         AND t.status = 'active'
         ORDER BY t.full_name",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    Ok(parent_children_teachers
        .into_iter()
        .map(|(id, name)| RelatedTeacher {
            user_id: id,
            name,
        })
        .collect())
}

/// Check if a user can view a specific thread
async fn can_view_thread(
    pool: &PgPool,
    user_id: i32,
    thread_id: i32,
) -> Result<bool, sqlx::Error> {
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
             WHERE is_admin_chat = false
             AND (participant_a_id = $1 OR participant_b_id = $1)
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
                "SELECT COALESCE(
                    (SELECT full_name FROM students WHERE user_id = $1),
                    (SELECT full_name FROM parents WHERE user_id = $1),
                    (SELECT full_name FROM teachers WHERE user_id = $1),
                    (SELECT username FROM users WHERE id = $1)
                )",
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
            "SELECT id, thread_id, sender_id, body, created_at
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
                "SELECT COALESCE(
                    (SELECT full_name FROM students WHERE user_id = $1),
                    (SELECT full_name FROM parents WHERE user_id = $1),
                    (SELECT full_name FROM teachers WHERE user_id = $1),
                    (SELECT username FROM users WHERE id = $1)
                )",
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

            Some(ChatMessageResponse {
                id: msg.id,
                sender_id: msg.sender_id,
                sender_name,
                body: msg.body,
                created_at: msg.created_at,
                receipts: receipts
                    .into_iter()
                    .map(|r| ReceiptResponse {
                        recipient_id: r.recipient_id,
                        state: r.state,
                        updated_at: r.updated_at,
                    })
                    .collect(),
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
             AND mr.state = 'sent'",
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
        "SELECT id, thread_id, sender_id, body, created_at
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

    let mut responses = Vec::new();
    for msg in messages {
        let sender_name = sqlx::query_scalar::<_, Option<String>>(
            "SELECT COALESCE(
                (SELECT full_name FROM students WHERE user_id = $1),
                (SELECT full_name FROM parents WHERE user_id = $1),
                (SELECT full_name FROM teachers WHERE user_id = $1),
                (SELECT username FROM users WHERE id = $1)
            )",
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
            receipts: receipts
                .into_iter()
                .map(|r| ReceiptResponse {
                    recipient_id: r.recipient_id,
                    state: r.state,
                    updated_at: r.updated_at,
                })
                .collect(),
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
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let target_id = payload.target_user_id;

    // Check if users can message each other
    let can_message = can_message_user(&app_state.db, user_id, target_id)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

    if !can_message {
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
        // For admin chat, all admins are recipients
        sqlx::query_scalar::<_, i32>(
            "SELECT DISTINCT ur.user_id
             FROM user_roles ur
             JOIN roles r ON ur.role_id = r.id
             WHERE r.name = 'admin'
             AND ur.user_id != $1",
        )
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?
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
    let message_id = sqlx::query_scalar::<_, i32>(
        "INSERT INTO chat_messages (thread_id, sender_id, body)
         VALUES ($1, $2, $3)
         RETURNING id",
    )
    .bind(thread_id)
    .bind(user_id)
    .bind(&payload.body)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

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
    let message_data = serde_json::json!({
        "message_id": message_id,
        "thread_id": thread_id,
        "sender_id": user_id,
        "sender_name": sender_name,
        "body": payload.body,
        "created_at": chrono::Utc::now().to_rfc3339(),
    });
    
    let ws_message = websockets::WsMessage {
        msg_type: "chat_message".to_string(),
        user_id: Some(user_id),
        thread_id: Some(thread_id),
        post_id: None,
        data: message_data,
    };
    
    app_state.ws_server.broadcast_to_thread(thread_id, ws_message).await;

    Ok(HttpResponse::Created().json(json!({
        "message_id": message_id,
        "recipients": recipients
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
        None => {
            sqlx::query_scalar::<_, i32>(
                "INSERT INTO chat_threads (participant_a_id, is_admin_chat)
                 VALUES ($1, true)
                 RETURNING id",
            )
            .bind(user_id)
            .fetch_one(&app_state.db)
            .await
            .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?
        }
    };

    // Insert message
    let message_id = sqlx::query_scalar::<_, i32>(
        "INSERT INTO chat_messages (thread_id, sender_id, body)
         VALUES ($1, $2, $3)
         RETURNING id",
    )
    .bind(thread_id)
    .bind(user_id)
    .bind(&payload.body)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| actix_web::error::ErrorInternalServerError(e.to_string()))?;

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
    let message_data = serde_json::json!({
        "message_id": message_id,
        "thread_id": thread_id,
        "sender_id": user_id,
        "sender_name": sender_name,
        "body": payload.body,
        "created_at": chrono::Utc::now().to_rfc3339(),
    });

    let ws_message = websockets::WsMessage {
        msg_type: "chat_message".to_string(),
        user_id: Some(user_id),
        thread_id: Some(thread_id),
        post_id: None,
        data: message_data,
    };

    app_state.ws_server.broadcast_to_thread(thread_id, ws_message).await;

    Ok(HttpResponse::Created().json(json!({
        "message_id": message_id,
        "thread_id": thread_id
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
            message_id,
            user_id,
            payload.state
        );
        return Ok(HttpResponse::BadRequest().json(json!({
            "error": "Invalid receipt state"
        })));
    }

    // Get thread_id for broadcasting
    let thread_id = sqlx::query_scalar::<_, i32>(
        "SELECT thread_id FROM chat_messages WHERE id = $1",
    )
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
            message_id,
            user_id
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
    
    app_state.ws_server.broadcast_to_thread(thread_id, ws_message).await;

    Ok(HttpResponse::Ok().json(json!({"state": payload.state})))
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

// ============================================================================
// Route Configuration
// ============================================================================

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/chat")
            .route("/threads", web::get().to(list_threads))
            .route("/threads", web::post().to(start_thread))
            .route("/threads/{thread_id}/messages", web::get().to(get_thread_messages))
            .route("/threads/{thread_id}/messages", web::post().to(send_message))
            .route("/messages/{message_id}/receipt", web::patch().to(update_receipt))
            .route("/admin/message", web::post().to(send_admin_message))
            .route("/related-teachers", web::get().to(get_related_teachers_handler)),
    );
}
