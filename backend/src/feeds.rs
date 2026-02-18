use actix_web::{web, HttpRequest, HttpResponse, Result};
use chrono::{DateTime, Utc};
use log::error;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value as JsonValue};
use sqlx::{FromRow, PgConnection, PgPool};
use std::collections::{HashMap, HashSet};

use crate::chats::{ChatAttachmentInput, ChatAttachmentResponse};
use crate::notification_builders::{build_feed_comment_notification, build_feed_post_notification};
use crate::notifications::is_user_notification_eligible;
use crate::notifications::NotificationBody;
use crate::push;
use crate::users::verify_token;
use crate::websockets;
use crate::AppState;

#[derive(Debug, Serialize, FromRow, Clone)]
pub struct Feed {
    pub id: i32,
    pub owner_type: String,
    pub owner_user_id: Option<i32>,
    pub owner_group_id: Option<i32>,
    pub title: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow)]
pub struct FeedSettings {
    pub feed_id: i32,
    pub allow_student_posts: bool,
}

#[derive(Debug, Serialize, FromRow)]
pub struct FeedUserSettings {
    pub feed_id: i32,
    pub user_id: i32,
    pub auto_subscribe_new_posts: bool,
    pub notify_new_posts: bool,
}

#[derive(Debug, Serialize, FromRow)]
pub struct FeedPost {
    pub id: i32,
    pub feed_id: i32,
    pub author_user_id: i32,
    pub title: Option<String>,
    pub content: JsonValue,
    pub is_important: bool,
    pub important_rank: Option<i32>,
    pub allow_comments: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub is_read: bool,
}

#[derive(Debug, Serialize, FromRow)]
pub struct FeedComment {
    pub id: i32,
    pub post_id: i32,
    pub author_user_id: i32,
    pub parent_comment_id: Option<i32>,
    pub content: JsonValue,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Clone)]
pub struct FeedPostResponse {
    pub id: i32,
    pub feed_id: i32,
    pub author_user_id: i32,
    pub title: Option<String>,
    pub content: JsonValue,
    pub is_important: bool,
    pub important_rank: Option<i32>,
    pub allow_comments: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub is_read: bool,
    pub attachments: Vec<ChatAttachmentResponse>,
}

#[derive(Debug, Serialize, Clone)]
pub struct FeedCommentResponse {
    pub id: i32,
    pub post_id: i32,
    pub author_user_id: i32,
    pub parent_comment_id: Option<i32>,
    pub content: JsonValue,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub attachments: Vec<ChatAttachmentResponse>,
}

#[derive(Debug, Deserialize)]
pub struct PostListQuery {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    pub important_only: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct CreatePostRequest {
    pub title: Option<String>,
    pub content: JsonValue,
    pub is_important: Option<bool>,
    pub important_rank: Option<i32>,
    pub allow_comments: Option<bool>,
    pub attachments: Option<Vec<ChatAttachmentInput>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateCommentRequest {
    pub parent_comment_id: Option<i32>,
    pub content: JsonValue,
    pub attachments: Option<Vec<ChatAttachmentInput>>,
}

#[derive(Debug, Deserialize)]
pub struct UpdatePostRequest {
    pub title: Option<String>,
    pub content: Option<JsonValue>,
    pub is_important: Option<bool>,
    pub important_rank: Option<i32>,
    pub allow_comments: Option<bool>,
    pub attachments: Option<Vec<ChatAttachmentInput>>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateCommentRequest {
    pub content: Option<JsonValue>,
    pub attachments: Option<Vec<ChatAttachmentInput>>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateFeedSettingsRequest {
    pub allow_student_posts: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateFeedUserSettingsRequest {
    pub auto_subscribe_new_posts: bool,
    pub notify_new_posts: bool,
}

#[derive(Debug, Deserialize)]
pub struct UpdateSubscriptionRequest {
    pub notify_on_comments: bool,
}

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

fn is_valid_attachment_type(value: &str) -> bool {
    matches!(value, "image" | "audio" | "voice" | "video" | "file")
}

#[derive(Debug, FromRow)]
struct FeedPostAttachmentRow {
    pub post_id: i32,
    pub media_id: i32,
    pub attachment_type: String,
    pub public_url: String,
    pub mime_type: String,
    pub size_bytes: i32,
}

#[derive(Debug, FromRow)]
struct FeedCommentAttachmentRow {
    pub comment_id: i32,
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

async fn load_attachments_for_posts(
    db: &PgPool,
    post_ids: &[i32],
) -> Result<HashMap<i32, Vec<ChatAttachmentResponse>>, sqlx::Error> {
    if post_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let rows = sqlx::query_as::<_, FeedPostAttachmentRow>(
        "SELECT fpm.post_id,
                fpm.media_id,
                fpm.attachment_type::text as attachment_type,
                mf.public_url,
                mf.mime_type,
                mf.size_bytes
         FROM feed_post_media fpm
         JOIN media_files mf ON fpm.media_id = mf.id
         WHERE fpm.post_id = ANY($1)
         ORDER BY fpm.sort_order, fpm.media_id",
    )
    .bind(post_ids)
    .fetch_all(db)
    .await?;

    let mut map: HashMap<i32, Vec<ChatAttachmentResponse>> = HashMap::new();
    for row in rows {
        map.entry(row.post_id)
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

async fn load_attachments_for_comments(
    db: &PgPool,
    comment_ids: &[i32],
) -> Result<HashMap<i32, Vec<ChatAttachmentResponse>>, sqlx::Error> {
    if comment_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let rows = sqlx::query_as::<_, FeedCommentAttachmentRow>(
        "SELECT fcm.comment_id,
                fcm.media_id,
                fcm.attachment_type::text as attachment_type,
                mf.public_url,
                mf.mime_type,
                mf.size_bytes
         FROM feed_comment_media fcm
         JOIN media_files mf ON fcm.media_id = mf.id
         WHERE fcm.comment_id = ANY($1)
         ORDER BY fcm.sort_order, fcm.media_id",
    )
    .bind(comment_ids)
    .fetch_all(db)
    .await?;

    let mut map: HashMap<i32, Vec<ChatAttachmentResponse>> = HashMap::new();
    for row in rows {
        map.entry(row.comment_id)
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

async fn store_post_attachments(
    tx: &mut PgConnection,
    user_id: i32,
    post_id: i32,
    attachments: &[ChatAttachmentInput],
) -> Result<Vec<ChatAttachmentResponse>, HttpResponse> {
    if attachments.is_empty() {
        return Ok(Vec::new());
    }

    let mut stored = Vec::new();

    for (index, attachment) in attachments.iter().enumerate() {
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
        .fetch_optional(&mut *tx)
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
            "INSERT INTO feed_post_media (post_id, media_id, attachment_type, sort_order)
             VALUES ($1, $2, $3::chat_attachment_type, $4)",
        )
        .bind(post_id)
        .bind(media.id)
        .bind(&attachment.attachment_type)
        .bind(index as i32)
        .execute(&mut *tx)
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

async fn store_comment_attachments(
    tx: &mut PgConnection,
    user_id: i32,
    comment_id: i32,
    attachments: &[ChatAttachmentInput],
) -> Result<Vec<ChatAttachmentResponse>, HttpResponse> {
    if attachments.is_empty() {
        return Ok(Vec::new());
    }

    let mut stored = Vec::new();

    for (index, attachment) in attachments.iter().enumerate() {
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
        .fetch_optional(&mut *tx)
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
            "INSERT INTO feed_comment_media (comment_id, media_id, attachment_type, sort_order)
             VALUES ($1, $2, $3::chat_attachment_type, $4)",
        )
        .bind(comment_id)
        .bind(media.id)
        .bind(&attachment.attachment_type)
        .bind(index as i32)
        .execute(&mut *tx)
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

async fn insert_notification(db: &PgPool, user_id: i32, body: &NotificationBody, priority: &str) {
    if !is_user_notification_eligible(db, user_id).await {
        return;
    }

    let notification_id = sqlx::query_scalar::<_, i32>(
        "INSERT INTO notifications (user_id, type, title, body, priority)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id",
    )
    .bind(user_id)
    .bind(&body.body_type)
    .bind(&body.title)
    .bind(serde_json::to_value(body).unwrap_or_default())
    .bind(priority)
    .fetch_optional(db)
    .await
    .unwrap_or(None);

    if let Some(notification_id) = notification_id {
        push::send_notification_to_user(db, user_id, body, Some(notification_id)).await;
    }
}

fn is_admin(claims: &crate::users::Claims) -> bool {
    claims.roles.iter().any(|role| role == "admin")
}

async fn fetch_feed(app_state: &AppState, feed_id: i32) -> Result<Feed> {
    sqlx::query_as::<_, Feed>(
        "SELECT id, owner_type::text as owner_type, owner_user_id, owner_group_id, title, created_at FROM feeds WHERE id = $1"
    )
    .bind(feed_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feed")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Feed not found"))
}

async fn ensure_feed_access(
    app_state: &AppState,
    feed: &Feed,
    user_id: i32,
    claims: &crate::users::Claims,
) -> Result<()> {
    if is_admin(claims) {
        return Ok(());
    }

    if feed.owner_type == "school" {
        return Ok(());
    }

    if feed.owner_type == "teacher" {
        if feed.owner_user_id == Some(user_id) {
            return Ok(());
        }

        let has_access: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM teacher_student_relations tsr
                WHERE tsr.teacher_user_id = $1 AND tsr.student_user_id = $2
            ) OR EXISTS(
                SELECT 1
                FROM parent_student_relations psr
                JOIN parents p ON p.user_id = psr.parent_user_id
                JOIN teacher_student_relations tsr
                    ON tsr.student_user_id = psr.student_user_id
                WHERE psr.parent_user_id = $2
                  AND tsr.teacher_user_id = $1
                  AND p.status = 'active'
            )
            "#,
        )
        .bind(feed.owner_user_id)
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error checking feed access: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to check access")
        })?;

        if has_access {
            return Ok(());
        }
    }

    if feed.owner_type == "group" {
        let has_access: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
                SELECT 1
                FROM student_groups sg
                WHERE sg.id = $1
                  AND sg.teacher_user_id = $2
                                    AND sg.status = 'active'
            ) OR EXISTS(
                SELECT 1
                FROM group_student_relations gsr
                                JOIN student_groups sg ON sg.id = gsr.group_id
                WHERE gsr.group_id = $1
                  AND gsr.student_user_id = $2
                                    AND sg.status = 'active'
            ) OR EXISTS(
                SELECT 1
                FROM group_student_relations gsr
                                JOIN student_groups sg ON sg.id = gsr.group_id
                JOIN parent_student_relations psr ON psr.student_user_id = gsr.student_user_id
                JOIN parents p ON p.user_id = psr.parent_user_id
                WHERE gsr.group_id = $1
                  AND psr.parent_user_id = $2
                                    AND sg.status = 'active'
                  AND p.status = 'active'
            )
            "#,
        )
        .bind(feed.owner_group_id)
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error checking group feed access: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to check access")
        })?;

        if has_access {
            return Ok(());
        }
    }

    Err(actix_web::error::ErrorForbidden("Access denied"))
}

async fn ensure_feed_owner(
    _app_state: &AppState,
    feed: &Feed,
    user_id: i32,
    claims: &crate::users::Claims,
) -> Result<()> {
    if is_admin(claims) && feed.owner_type == "school" {
        return Ok(());
    }

    if feed.owner_type == "teacher" && feed.owner_user_id == Some(user_id) {
        return Ok(());
    }

    if feed.owner_type == "group" {
        let is_group_owner = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1
                FROM student_groups
                WHERE id = $1 AND teacher_user_id = $2 AND status = 'active'
            )",
        )
        .bind(feed.owner_group_id)
        .bind(user_id)
        .fetch_one(&_app_state.db)
        .await
        .unwrap_or(false);

        if is_group_owner {
            return Ok(());
        }
    }

    Err(actix_web::error::ErrorForbidden("Not allowed"))
}

fn can_edit_post(
    feed: &Feed,
    post_author_id: i32,
    user_id: i32,
    claims: &crate::users::Claims,
) -> bool {
    if feed.owner_type == "school" {
        return is_admin(claims) || post_author_id == user_id;
    }

    post_author_id == user_id
}

pub async fn list_feeds(req: HttpRequest, app_state: web::Data<AppState>) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let mut feeds: Vec<Feed> = Vec::new();

    let school_feeds = sqlx::query_as::<_, Feed>(
        "SELECT id, owner_type::text as owner_type, owner_user_id, owner_group_id, title, created_at FROM feeds WHERE owner_type = 'school'"
    )
    .fetch_all(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching school feeds: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
    })?;
    feeds.extend(school_feeds);

    if claims.roles.iter().any(|role| role == "teacher") {
        let teacher_feeds = sqlx::query_as::<_, Feed>(
            "SELECT id, owner_type::text as owner_type, owner_user_id, owner_group_id, title, created_at FROM feeds WHERE owner_type = 'teacher' AND owner_user_id = $1"
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching teacher feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(teacher_feeds);

        let group_feeds = sqlx::query_as::<_, Feed>(
            "SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
             FROM feeds f
             JOIN student_groups sg ON sg.id = f.owner_group_id
               WHERE f.owner_type = 'group' AND sg.teacher_user_id = $1 AND sg.status = 'active'",
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching teacher group feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(group_feeds);
    }

    if claims.roles.iter().any(|role| role == "student") {
        let student_feeds = sqlx::query_as::<_, Feed>(
            r#"
            SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
            FROM feeds f
            JOIN teacher_student_relations tsr ON tsr.teacher_user_id = f.owner_user_id
            WHERE f.owner_type = 'teacher' AND tsr.student_user_id = $1
            "#,
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching student feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(student_feeds);

        let student_group_feeds = sqlx::query_as::<_, Feed>(
            r#"
            SELECT DISTINCT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
            FROM feeds f
            JOIN group_student_relations gsr ON gsr.group_id = f.owner_group_id
            JOIN student_groups sg ON sg.id = gsr.group_id
            WHERE f.owner_type = 'group' AND gsr.student_user_id = $1 AND sg.status = 'active'
            "#,
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching student group feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(student_group_feeds);
    }

    if claims.roles.iter().any(|role| role == "parent") {
        let parent_feeds = sqlx::query_as::<_, Feed>(
            r#"
            SELECT DISTINCT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
            FROM feeds f
            JOIN parent_student_relations psr ON psr.parent_user_id = $1
            JOIN parents p ON p.user_id = psr.parent_user_id
            JOIN teacher_student_relations tsr ON tsr.student_user_id = psr.student_user_id
                AND tsr.teacher_user_id = f.owner_user_id
            WHERE f.owner_type = 'teacher'
              AND p.status = 'active'
            "#
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching parent feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(parent_feeds);

        let parent_group_feeds = sqlx::query_as::<_, Feed>(
            r#"
            SELECT DISTINCT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
            FROM feeds f
            JOIN parent_student_relations psr ON psr.parent_user_id = $1
            JOIN parents p ON p.user_id = psr.parent_user_id
            JOIN group_student_relations gsr ON gsr.student_user_id = psr.student_user_id
                        JOIN student_groups sg ON sg.id = gsr.group_id
            WHERE f.owner_type = 'group'
              AND f.owner_group_id = gsr.group_id
                            AND sg.status = 'active'
              AND p.status = 'active'
            "#,
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching parent group feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(parent_group_feeds);
    }

    let mut seen = HashSet::new();
    feeds.retain(|feed| seen.insert(feed.id));

    Ok(HttpResponse::Ok().json(feeds))
}

pub async fn get_feed_settings(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let settings = sqlx::query_as::<_, FeedSettings>(
        r#"
        INSERT INTO feed_settings (feed_id)
        VALUES ($1)
        ON CONFLICT (feed_id) DO UPDATE SET feed_id = EXCLUDED.feed_id
        RETURNING feed_id, allow_student_posts
        "#,
    )
    .bind(*feed_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed settings: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feed settings")
    })?;

    Ok(HttpResponse::Ok().json(settings))
}

pub async fn update_feed_settings(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
    payload: web::Json<UpdateFeedSettingsRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_owner(&app_state, &feed, user_id, &claims).await?;

    let settings = sqlx::query_as::<_, FeedSettings>(
        r#"
        INSERT INTO feed_settings (feed_id, allow_student_posts)
        VALUES ($1, $2)
        ON CONFLICT (feed_id) DO UPDATE SET allow_student_posts = EXCLUDED.allow_student_posts
        RETURNING feed_id, allow_student_posts
        "#,
    )
    .bind(*feed_id)
    .bind(payload.allow_student_posts)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error updating feed settings: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update feed settings")
    })?;

    Ok(HttpResponse::Ok().json(settings))
}

pub async fn get_feed_user_settings(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let settings = sqlx::query_as::<_, FeedUserSettings>(
        r#"
        INSERT INTO feed_user_settings (feed_id, user_id)
        VALUES ($1, $2)
        ON CONFLICT (feed_id, user_id) DO UPDATE SET feed_id = EXCLUDED.feed_id
        RETURNING feed_id, user_id, auto_subscribe_new_posts, notify_new_posts
        "#,
    )
    .bind(*feed_id)
    .bind(user_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed user settings: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feed user settings")
    })?;

    Ok(HttpResponse::Ok().json(settings))
}

pub async fn update_feed_user_settings(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
    payload: web::Json<UpdateFeedUserSettingsRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let settings = sqlx::query_as::<_, FeedUserSettings>(
        r#"
        INSERT INTO feed_user_settings (feed_id, user_id, auto_subscribe_new_posts, notify_new_posts)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (feed_id, user_id)
            DO UPDATE SET auto_subscribe_new_posts = EXCLUDED.auto_subscribe_new_posts,
                          notify_new_posts = EXCLUDED.notify_new_posts
        RETURNING feed_id, user_id, auto_subscribe_new_posts, notify_new_posts
        "#
    )
    .bind(*feed_id)
    .bind(user_id)
    .bind(payload.auto_subscribe_new_posts)
    .bind(payload.notify_new_posts)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error updating feed user settings: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update feed user settings")
    })?;

    Ok(HttpResponse::Ok().json(settings))
}

pub async fn list_posts(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
    query: web::Query<PostListQuery>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let important_only = query.important_only.unwrap_or(false);
    let mut limit = query.limit.unwrap_or(20).min(50);
    let offset = query.offset.unwrap_or(0);

    if important_only {
        limit = limit.min(5);
    }

    let mut builder = sqlx::QueryBuilder::new(
        "SELECT fp.id, fp.feed_id, fp.author_user_id, fp.title, fp.content, fp.is_important, fp.important_rank, fp.allow_comments, fp.created_at, fp.updated_at, (fpr.read_at IS NOT NULL) AS is_read FROM feed_posts fp LEFT JOIN feed_post_reads fpr ON fpr.post_id = fp.id AND fpr.user_id = "
    );
    builder.push_bind(user_id);
    builder.push(" WHERE fp.feed_id = ");
    builder.push_bind(*feed_id);

    if important_only {
        builder.push(" AND fp.is_important = true");
        builder.push(" ORDER BY fp.important_rank NULLS LAST, fp.created_at DESC");
    } else {
        builder.push(" ORDER BY fp.created_at DESC");
    }

    builder.push(" LIMIT ");
    builder.push_bind(limit);
    builder.push(" OFFSET ");
    builder.push_bind(offset);

    let posts = builder
        .build_query_as::<FeedPost>()
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error fetching posts: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch posts")
        })?;

    let post_ids: Vec<i32> = posts.iter().map(|post| post.id).collect();
    let attachments_map = load_attachments_for_posts(&app_state.db, &post_ids)
        .await
        .map_err(|e| {
            error!("Database error fetching post attachments: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch post attachments")
        })?;

    let responses: Vec<FeedPostResponse> = posts
        .into_iter()
        .map(|post| FeedPostResponse {
            id: post.id,
            feed_id: post.feed_id,
            author_user_id: post.author_user_id,
            title: post.title,
            content: post.content,
            is_important: post.is_important,
            important_rank: post.important_rank,
            allow_comments: post.allow_comments,
            created_at: post.created_at,
            updated_at: post.updated_at,
            is_read: post.is_read,
            attachments: attachments_map.get(&post.id).cloned().unwrap_or_default(),
        })
        .collect();

    Ok(HttpResponse::Ok().json(responses))
}

pub async fn get_post(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let post = sqlx::query_as::<_, FeedPost>(
        "SELECT fp.id, fp.feed_id, fp.author_user_id, fp.title, fp.content, fp.is_important, fp.important_rank, fp.allow_comments, fp.created_at, fp.updated_at, (fpr.read_at IS NOT NULL) AS is_read FROM feed_posts fp LEFT JOIN feed_post_reads fpr ON fpr.post_id = fp.id AND fpr.user_id = $2 WHERE fp.id = $1"
    )
    .bind(*post_id)
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    let feed = fetch_feed(&app_state, post.feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let attachments_map = load_attachments_for_posts(&app_state.db, &[post.id])
        .await
        .map_err(|e| {
            error!("Database error fetching post attachments: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch post attachments")
        })?;

    let response = FeedPostResponse {
        id: post.id,
        feed_id: post.feed_id,
        author_user_id: post.author_user_id,
        title: post.title,
        content: post.content,
        is_important: post.is_important,
        important_rank: post.important_rank,
        allow_comments: post.allow_comments,
        created_at: post.created_at,
        updated_at: post.updated_at,
        is_read: post.is_read,
        attachments: attachments_map.get(&post.id).cloned().unwrap_or_default(),
    };

    Ok(HttpResponse::Ok().json(response))
}

pub async fn mark_post_read(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed for read mark: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark post as read")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    sqlx::query(
        r#"
        INSERT INTO feed_post_reads (post_id, user_id, read_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (post_id, user_id) DO UPDATE SET read_at = EXCLUDED.read_at
        "#,
    )
    .bind(*post_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error marking post read: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark post as read")
    })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "marked": true
    })))
}

pub async fn mark_feed_read(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let result = sqlx::query(
        r#"
        INSERT INTO feed_post_reads (post_id, user_id, read_at)
        SELECT p.id, $2, NOW()
        FROM feed_posts p
        WHERE p.feed_id = $1
        ON CONFLICT (post_id, user_id) DO UPDATE SET read_at = EXCLUDED.read_at
        "#,
    )
    .bind(*feed_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error marking feed read: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark feed as read")
    })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "updated": result.rows_affected()
    })))
}

pub async fn create_post(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    feed_id: web::Path<i32>,
    payload: web::Json<CreatePostRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let feed = fetch_feed(&app_state, *feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let settings = sqlx::query_as::<_, FeedSettings>(
        r#"
        INSERT INTO feed_settings (feed_id)
        VALUES ($1)
        ON CONFLICT (feed_id) DO UPDATE SET feed_id = EXCLUDED.feed_id
        RETURNING feed_id, allow_student_posts
        "#,
    )
    .bind(*feed_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed settings: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feed settings")
    })?;

    let is_teacher_owner = feed.owner_type == "teacher" && feed.owner_user_id == Some(user_id);
    let is_group_owner = if feed.owner_type == "group" {
        sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(
                SELECT 1 FROM student_groups
                WHERE id = $1 AND teacher_user_id = $2 AND status = 'active'
            )",
        )
        .bind(feed.owner_group_id)
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .unwrap_or(false)
    } else {
        false
    };
    let can_post = is_admin(&claims)
        || is_teacher_owner
        || is_group_owner
        || (settings.allow_student_posts && claims.roles.iter().any(|role| role == "student"));

    if !can_post {
        return Err(actix_web::error::ErrorForbidden("Not allowed to post"));
    }

    let is_important = payload.is_important.unwrap_or(false);
    let allow_comments = payload.allow_comments.unwrap_or(true);

    let mut tx = app_state.db.begin().await.map_err(|e| {
        error!("Database error starting transaction: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create post")
    })?;

    let post = sqlx::query_as::<_, FeedPost>(
        r#"
        INSERT INTO feed_posts (feed_id, author_user_id, title, content, is_important, important_rank, allow_comments)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id, feed_id, author_user_id, title, content, is_important, important_rank, allow_comments, created_at, updated_at, TRUE as is_read
        "#
    )
    .bind(*feed_id)
    .bind(user_id)
    .bind(&payload.title)
    .bind(&payload.content)
    .bind(is_important)
    .bind(payload.important_rank)
    .bind(allow_comments)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error creating post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create post")
    })?;

    sqlx::query(
        r#"
        INSERT INTO feed_post_reads (post_id, user_id, read_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (post_id, user_id) DO UPDATE SET read_at = EXCLUDED.read_at
        "#,
    )
    .bind(post.id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error marking post as read: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark post as read")
    })?;

    let attachments = if let Some(items) = payload.attachments.as_deref() {
        match store_post_attachments(&mut *tx, user_id, post.id, items).await {
            Ok(saved) => saved,
            Err(response) => return Ok(response),
        }
    } else {
        Vec::new()
    };

    sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        VALUES ($1, $2, TRUE)
        ON CONFLICT (post_id, user_id) DO NOTHING
        "#,
    )
    .bind(post.id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error creating author subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create subscriptions")
    })?;

    sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        SELECT $1, fus.user_id, TRUE
        FROM feed_user_settings fus
        WHERE fus.feed_id = $2 AND fus.auto_subscribe_new_posts = TRUE
        ON CONFLICT (post_id, user_id) DO NOTHING
        "#,
    )
    .bind(post.id)
    .bind(*feed_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error auto-subscribing users: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create subscriptions")
    })?;

    tx.commit().await.map_err(|e| {
        error!("Database error committing post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create post")
    })?;

    let recipients = sqlx::query_scalar::<_, i32>(
        r#"
        SELECT user_id
        FROM feed_user_settings
        WHERE feed_id = $1 AND notify_new_posts = TRUE AND user_id <> $2
        "#,
    )
    .bind(*feed_id)
    .bind(user_id)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default();

    if !recipients.is_empty() {
        let post_title = post.title.as_deref().unwrap_or("");
        let body = build_feed_post_notification(&feed.title, post_title, feed.id, post.id);
        let priority = if post.is_important { "high" } else { "normal" };
        for recipient_id in recipients {
            insert_notification(&app_state.db, recipient_id, &body, priority).await;
        }
    }

    let response = FeedPostResponse {
        id: post.id,
        feed_id: post.feed_id,
        author_user_id: post.author_user_id,
        title: post.title,
        content: post.content,
        is_important: post.is_important,
        important_rank: post.important_rank,
        allow_comments: post.allow_comments,
        created_at: post.created_at,
        updated_at: post.updated_at,
        is_read: post.is_read,
        attachments,
    };

    Ok(HttpResponse::Created().json(response))
}

pub async fn list_comments(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed for comments: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch comments")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let comments = sqlx::query_as::<_, FeedComment>(
        "SELECT id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at FROM feed_comments WHERE post_id = $1 ORDER BY created_at ASC"
    )
    .bind(*post_id)
    .fetch_all(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching comments: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch comments")
    })?;

    let comment_ids: Vec<i32> = comments.iter().map(|comment| comment.id).collect();
    let attachments_map = load_attachments_for_comments(&app_state.db, &comment_ids)
        .await
        .map_err(|e| {
            error!("Database error fetching comment attachments: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch comment attachments")
        })?;

    let responses: Vec<FeedCommentResponse> = comments
        .into_iter()
        .map(|comment| FeedCommentResponse {
            id: comment.id,
            post_id: comment.post_id,
            author_user_id: comment.author_user_id,
            parent_comment_id: comment.parent_comment_id,
            content: comment.content,
            created_at: comment.created_at,
            updated_at: comment.updated_at,
            attachments: attachments_map
                .get(&comment.id)
                .cloned()
                .unwrap_or_default(),
        })
        .collect();

    Ok(HttpResponse::Ok().json(responses))
}

pub async fn create_comment(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
    payload: web::Json<CreateCommentRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let post = sqlx::query_as::<_, FeedPost>(
        "SELECT fp.id, fp.feed_id, fp.author_user_id, fp.title, fp.content, fp.is_important, fp.important_rank, fp.allow_comments, fp.created_at, fp.updated_at, (fpr.read_at IS NOT NULL) AS is_read FROM feed_posts fp LEFT JOIN feed_post_reads fpr ON fpr.post_id = fp.id AND fpr.user_id = $2 WHERE fp.id = $1"
    )
    .bind(*post_id)
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    if !post.allow_comments {
        return Err(actix_web::error::ErrorBadRequest(
            "Comments are disabled for this post",
        ));
    }

    let feed = fetch_feed(&app_state, post.feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let mut tx = app_state.db.begin().await.map_err(|e| {
        error!("Database error starting transaction: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create comment")
    })?;

    let comment = sqlx::query_as::<_, FeedComment>(
        r#"
        INSERT INTO feed_comments (post_id, author_user_id, parent_comment_id, content)
        VALUES ($1, $2, $3, $4)
        RETURNING id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at
        "#,
    )
    .bind(*post_id)
    .bind(user_id)
    .bind(payload.parent_comment_id)
    .bind(&payload.content)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error creating comment: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create comment")
    })?;

    let attachments = if let Some(items) = payload.attachments.as_deref() {
        match store_comment_attachments(&mut *tx, user_id, comment.id, items).await {
            Ok(saved) => saved,
            Err(response) => return Ok(response),
        }
    } else {
        Vec::new()
    };

    sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        VALUES ($1, $2, TRUE)
        ON CONFLICT (post_id, user_id) DO UPDATE SET notify_on_comments = TRUE
        "#,
    )
    .bind(*post_id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error creating comment subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to subscribe")
    })?;

    tx.commit().await.map_err(|e| {
        error!("Database error committing comment: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create comment")
    })?;

    let recipients = sqlx::query_scalar::<_, i32>(
        r#"
        SELECT user_id
        FROM feed_post_subscriptions
        WHERE post_id = $1 AND notify_on_comments = TRUE AND user_id <> $2
        "#,
    )
    .bind(*post_id)
    .bind(user_id)
    .fetch_all(&app_state.db)
    .await
    .unwrap_or_default();

    if !recipients.is_empty() {
        let post_title = post.title.as_deref().unwrap_or("");
        let body = build_feed_comment_notification(&feed.title, post_title, feed.id, post.id);
        for recipient_id in recipients {
            insert_notification(&app_state.db, recipient_id, &body, "normal").await;
        }
    }

    let comment_response = FeedCommentResponse {
        id: comment.id,
        post_id: comment.post_id,
        author_user_id: comment.author_user_id,
        parent_comment_id: comment.parent_comment_id,
        content: comment.content,
        created_at: comment.created_at,
        updated_at: comment.updated_at,
        attachments: attachments.clone(),
    };

    let comment_data =
        serde_json::to_value(&comment_response).unwrap_or_else(|_| serde_json::json!({}));
    let ws_message = websockets::WsMessage {
        msg_type: "comment".to_string(),
        user_id: Some(user_id),
        thread_id: None,
        post_id: Some(*post_id),
        data: comment_data,
    };
    app_state
        .ws_server
        .broadcast_to_post(*post_id, ws_message)
        .await;

    Ok(HttpResponse::Created().json(comment_response))
}

pub async fn update_post(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
    payload: web::Json<UpdatePostRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let post = sqlx::query_as::<_, FeedPost>(
        "SELECT fp.id, fp.feed_id, fp.author_user_id, fp.title, fp.content, fp.is_important, fp.important_rank, fp.allow_comments, fp.created_at, fp.updated_at, (fpr.read_at IS NOT NULL) AS is_read FROM feed_posts fp LEFT JOIN feed_post_reads fpr ON fpr.post_id = fp.id AND fpr.user_id = $2 WHERE fp.id = $1"
    )
    .bind(*post_id)
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    let feed = fetch_feed(&app_state, post.feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    if !can_edit_post(&feed, post.author_user_id, user_id, &claims) {
        return Err(actix_web::error::ErrorForbidden("Not allowed"));
    }

    let new_title = payload.title.clone().or(post.title);
    let new_content = payload.content.clone().unwrap_or(post.content);
    let new_is_important = payload.is_important.unwrap_or(post.is_important);
    let new_important_rank = if payload.is_important == Some(false) {
        None
    } else {
        payload.important_rank.or(post.important_rank)
    };
    let new_allow_comments = payload.allow_comments.unwrap_or(post.allow_comments);

    let mut tx = app_state.db.begin().await.map_err(|e| {
        error!("Database error starting transaction: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update post")
    })?;

    let attachments = if let Some(items) = payload.attachments.as_deref() {
        sqlx::query("DELETE FROM feed_post_media WHERE post_id = $1")
            .bind(post.id)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                error!("Database error clearing post media: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to update post")
            })?;

        match store_post_attachments(&mut *tx, user_id, post.id, items).await {
            Ok(saved) => Some(saved),
            Err(response) => return Ok(response),
        }
    } else {
        None
    };

    sqlx::query(
        r#"
        UPDATE feed_posts
        SET title = $1,
            content = $2,
            is_important = $3,
            important_rank = $4,
            allow_comments = $5
        WHERE id = $6
        "#,
    )
    .bind(&new_title)
    .bind(&new_content)
    .bind(new_is_important)
    .bind(new_important_rank)
    .bind(new_allow_comments)
    .bind(post.id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error updating post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update post")
    })?;

    let updated_post = sqlx::query_as::<_, FeedPost>(
        "SELECT fp.id, fp.feed_id, fp.author_user_id, fp.title, fp.content, fp.is_important, fp.important_rank, fp.allow_comments, fp.created_at, fp.updated_at, (fpr.read_at IS NOT NULL) AS is_read FROM feed_posts fp LEFT JOIN feed_post_reads fpr ON fpr.post_id = fp.id AND fpr.user_id = $2 WHERE fp.id = $1"
    )
    .bind(post.id)
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error fetching updated post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update post")
    })?;

    tx.commit().await.map_err(|e| {
        error!("Database error committing post update: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update post")
    })?;

    let final_attachments = if let Some(saved) = attachments {
        saved
    } else {
        load_attachments_for_posts(&app_state.db, &[post.id])
            .await
            .map_err(|e| {
                error!("Database error fetching post attachments: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to fetch post attachments")
            })?
            .get(&post.id)
            .cloned()
            .unwrap_or_default()
    };

    let response = FeedPostResponse {
        id: updated_post.id,
        feed_id: updated_post.feed_id,
        author_user_id: updated_post.author_user_id,
        title: updated_post.title,
        content: updated_post.content,
        is_important: updated_post.is_important,
        important_rank: updated_post.important_rank,
        allow_comments: updated_post.allow_comments,
        created_at: updated_post.created_at,
        updated_at: updated_post.updated_at,
        is_read: updated_post.is_read,
        attachments: final_attachments,
    };

    Ok(HttpResponse::Ok().json(response))
}

pub async fn update_comment(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
    payload: web::Json<UpdateCommentRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let (post_id, comment_id) = path.into_inner();

    let comment = sqlx::query_as::<_, FeedComment>(
        "SELECT id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at FROM feed_comments WHERE id = $1"
    )
    .bind(comment_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching comment: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update comment")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Comment not found"))?;

    if comment.author_user_id != user_id {
        return Err(actix_web::error::ErrorForbidden("Not allowed"));
    }

    if comment.post_id != post_id {
        return Err(actix_web::error::ErrorNotFound("Comment not found"));
    }

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(comment.post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed for comment: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update comment")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let new_content = payload.content.clone().unwrap_or(comment.content);

    let mut tx = app_state.db.begin().await.map_err(|e| {
        error!("Database error starting transaction: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update comment")
    })?;

    let attachments = if let Some(items) = payload.attachments.as_deref() {
        sqlx::query("DELETE FROM feed_comment_media WHERE comment_id = $1")
            .bind(comment.id)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                error!("Database error clearing comment media: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to update comment")
            })?;

        match store_comment_attachments(&mut *tx, user_id, comment.id, items).await {
            Ok(saved) => Some(saved),
            Err(response) => return Ok(response),
        }
    } else {
        None
    };

    let updated_comment = sqlx::query_as::<_, FeedComment>(
        r#"
        UPDATE feed_comments
        SET content = $1
        WHERE id = $2
        RETURNING id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at
        "#,
    )
    .bind(&new_content)
    .bind(comment.id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| {
        error!("Database error updating comment: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update comment")
    })?;

    tx.commit().await.map_err(|e| {
        error!("Database error committing comment update: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update comment")
    })?;

    let final_attachments = if let Some(saved) = attachments {
        saved
    } else {
        load_attachments_for_comments(&app_state.db, &[comment.id])
            .await
            .map_err(|e| {
                error!("Database error fetching comment attachments: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to fetch comment attachments")
            })?
            .get(&comment.id)
            .cloned()
            .unwrap_or_default()
    };

    let response = FeedCommentResponse {
        id: updated_comment.id,
        post_id: updated_comment.post_id,
        author_user_id: updated_comment.author_user_id,
        parent_comment_id: updated_comment.parent_comment_id,
        content: updated_comment.content,
        created_at: updated_comment.created_at,
        updated_at: updated_comment.updated_at,
        attachments: final_attachments,
    };

    let comment_data = serde_json::to_value(&response).unwrap_or_else(|_| serde_json::json!({}));
    let ws_message = websockets::WsMessage {
        msg_type: "comment".to_string(),
        user_id: Some(user_id),
        thread_id: None,
        post_id: Some(updated_comment.post_id),
        data: comment_data,
    };
    app_state
        .ws_server
        .broadcast_to_post(updated_comment.post_id, ws_message)
        .await;

    Ok(HttpResponse::Ok().json(response))
}

pub async fn update_post_subscription(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
    payload: web::Json<UpdateSubscriptionRequest>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed for subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update subscription")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let subscription = sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        VALUES ($1, $2, $3)
        ON CONFLICT (post_id, user_id)
            DO UPDATE SET notify_on_comments = EXCLUDED.notify_on_comments
        "#,
    )
    .bind(*post_id)
    .bind(user_id)
    .bind(payload.notify_on_comments)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error updating subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update subscription")
    })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "updated": subscription.rows_affected()
    })))
}

pub async fn get_post_subscription(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed for subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch subscription")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let notify_on_comments = sqlx::query_scalar::<_, bool>(
        "SELECT notify_on_comments FROM feed_post_subscriptions WHERE post_id = $1 AND user_id = $2"
    )
    .bind(*post_id)
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch subscription")
    })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "subscribed": notify_on_comments.unwrap_or(false),
        "notify_on_comments": notify_on_comments.unwrap_or(false)
    })))
}

pub async fn delete_post_subscription(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!(
            "Database error fetching feed for subscription removal: {:?}",
            e
        );
        actix_web::error::ErrorInternalServerError("Failed to update subscription")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let result =
        sqlx::query("DELETE FROM feed_post_subscriptions WHERE post_id = $1 AND user_id = $2")
            .bind(*post_id)
            .bind(user_id)
            .execute(&app_state.db)
            .await
            .map_err(|e| {
                error!("Database error deleting subscription: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to delete subscription")
            })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "deleted": result.rows_affected()
    })))
}

pub async fn delete_comment(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    path: web::Path<(i32, i32)>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;
    let (post_id, comment_id) = path.into_inner();

    let comment = sqlx::query_as::<_, FeedComment>(
        "SELECT id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at FROM feed_comments WHERE id = $1"
    )
    .bind(comment_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching comment for delete: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete comment")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Comment not found"))?;

    if comment.post_id != post_id {
        return Err(actix_web::error::ErrorNotFound("Comment not found"));
    }

    let feed = sqlx::query_as::<_, Feed>(
        r#"
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.owner_group_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#,
    )
    .bind(post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching feed for comment delete: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete comment")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    if comment.author_user_id != user_id {
        return Err(actix_web::error::ErrorForbidden("Not allowed"));
    }

    let mut tx = app_state.db.begin().await.map_err(|e| {
        error!(
            "Database error starting delete comment transaction: {:?}",
            e
        );
        actix_web::error::ErrorInternalServerError("Failed to delete comment")
    })?;

    sqlx::query("DELETE FROM feed_comment_media WHERE comment_id = $1")
        .bind(comment.id)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            error!("Database error deleting comment media: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to delete comment")
        })?;

    let deleted = sqlx::query("DELETE FROM feed_comments WHERE id = $1")
        .bind(comment.id)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            error!("Database error deleting comment: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to delete comment")
        })?;

    if deleted.rows_affected() == 0 {
        return Err(actix_web::error::ErrorNotFound("Comment not found"));
    }

    tx.commit().await.map_err(|e| {
        error!("Database error committing comment delete: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete comment")
    })?;

    Ok(HttpResponse::Ok().finish())
}

pub async fn delete_post(
    req: HttpRequest,
    app_state: web::Data<AppState>,
    post_id: web::Path<i32>,
) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    // Fetch the post to check authorization
    let post = sqlx::query_as::<_, FeedPost>(
        "SELECT fp.id, fp.feed_id, fp.author_user_id, fp.title, fp.content, fp.is_important, fp.important_rank, fp.allow_comments, fp.created_at, fp.updated_at, (fpr.read_at IS NOT NULL) AS is_read FROM feed_posts fp LEFT JOIN feed_post_reads fpr ON fpr.post_id = fp.id AND fpr.user_id = $2 WHERE fp.id = $1"
    )
    .bind(*post_id)
    .bind(user_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        error!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    let feed = fetch_feed(&app_state, post.feed_id).await?;
    if !can_edit_post(&feed, post.author_user_id, user_id, &claims) {
        return Err(actix_web::error::ErrorForbidden(
            "You do not have permission to delete this post",
        ));
    }

    // Delete the post (cascading deletes should handle comments and subscriptions)
    let result = sqlx::query("DELETE FROM feed_posts WHERE id = $1")
        .bind(*post_id)
        .execute(&app_state.db)
        .await
        .map_err(|e| {
            error!("Database error deleting post: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to delete post")
        })?;

    if result.rows_affected() == 0 {
        return Err(actix_web::error::ErrorNotFound("Post not found"));
    }

    Ok(HttpResponse::Ok().finish())
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/feeds")
            .route("", web::get().to(list_feeds))
            .route("/{feed_id}/settings", web::get().to(get_feed_settings))
            .route("/{feed_id}/settings", web::put().to(update_feed_settings))
            .route(
                "/{feed_id}/user-settings",
                web::get().to(get_feed_user_settings),
            )
            .route(
                "/{feed_id}/user-settings",
                web::put().to(update_feed_user_settings),
            )
            .route("/{feed_id}/posts", web::get().to(list_posts))
            .route("/{feed_id}/posts", web::post().to(create_post))
            .route("/{feed_id}/read", web::post().to(mark_feed_read))
            .route("/posts/{post_id}", web::get().to(get_post))
            .route("/posts/{post_id}", web::put().to(update_post))
            .route("/posts/{post_id}", web::delete().to(delete_post))
            .route("/posts/{post_id}/read", web::post().to(mark_post_read))
            .route("/posts/{post_id}/comments", web::get().to(list_comments))
            .route("/posts/{post_id}/comments", web::post().to(create_comment))
            .route(
                "/posts/{post_id}/comments/{comment_id}",
                web::put().to(update_comment),
            )
            .route(
                "/posts/{post_id}/comments/{comment_id}",
                web::delete().to(delete_comment),
            )
            .route(
                "/posts/{post_id}/subscribe",
                web::get().to(get_post_subscription),
            )
            .route(
                "/posts/{post_id}/subscribe",
                web::put().to(update_post_subscription),
            )
            .route(
                "/posts/{post_id}/subscribe",
                web::delete().to(delete_post_subscription),
            ),
    );
}
