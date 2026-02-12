use actix_web::{web, HttpRequest, HttpResponse, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use sqlx::{FromRow, PgPool};
use std::collections::HashSet;

use crate::users::verify_token;
use crate::notification_builders::{
    build_feed_comment_notification,
    build_feed_post_notification,
};
use crate::notifications::NotificationBody;
use crate::AppState;

#[derive(Debug, Serialize, FromRow, Clone)]
pub struct Feed {
    pub id: i32,
    pub owner_type: String,
    pub owner_user_id: Option<i32>,
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
    pub media_ids: Option<Vec<i32>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateCommentRequest {
    pub parent_comment_id: Option<i32>,
    pub content: JsonValue,
    pub media_ids: Option<Vec<i32>>,
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
        Err(_response) => return Err(actix_web::error::ErrorUnauthorized("Invalid or missing token")),
    };

    let user_id = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error getting user_id: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to get user information")
    })?
    .ok_or_else(|| actix_web::error::ErrorUnauthorized("User not found"))?;

    Ok(user_id)
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

fn is_admin(claims: &crate::users::Claims) -> bool {
    claims.roles.iter().any(|role| role == "admin")
}

async fn fetch_feed(app_state: &AppState, feed_id: i32) -> Result<Feed> {
    sqlx::query_as::<_, Feed>(
        "SELECT id, owner_type::text as owner_type, owner_user_id, title, created_at FROM feeds WHERE id = $1"
    )
    .bind(feed_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feed")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Feed not found"))
}

async fn ensure_feed_access(app_state: &AppState, feed: &Feed, user_id: i32, claims: &crate::users::Claims) -> Result<()> {
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
                JOIN teacher_student_relations tsr
                    ON tsr.student_user_id = psr.student_user_id
                WHERE psr.parent_user_id = $2 AND tsr.teacher_user_id = $1
            )
            "#
        )
        .bind(feed.owner_user_id)
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        .map_err(|e| {
            eprintln!("Database error checking feed access: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to check access")
        })?;

        if has_access {
            return Ok(());
        }
    }

    Err(actix_web::error::ErrorForbidden("Access denied"))
}

async fn ensure_feed_owner(app_state: &AppState, feed: &Feed, user_id: i32, claims: &crate::users::Claims) -> Result<()> {
    if is_admin(claims) && feed.owner_type == "school" {
        return Ok(());
    }

    if feed.owner_type == "teacher" && feed.owner_user_id == Some(user_id) {
        return Ok(());
    }

    Err(actix_web::error::ErrorForbidden("Not allowed"))
}

pub async fn list_feeds(req: HttpRequest, app_state: web::Data<AppState>) -> Result<HttpResponse> {
    let claims = verify_token(&req, &app_state)
        .map_err(|_response| actix_web::error::ErrorUnauthorized("Invalid or missing token"))?;
    let user_id = extract_user_id_from_token(&req, &app_state).await?;

    let mut feeds: Vec<Feed> = Vec::new();

    let school_feeds = sqlx::query_as::<_, Feed>(
        "SELECT id, owner_type::text as owner_type, owner_user_id, title, created_at FROM feeds WHERE owner_type = 'school'"
    )
    .fetch_all(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching school feeds: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
    })?;
    feeds.extend(school_feeds);

    if claims.roles.iter().any(|role| role == "teacher") {
        let teacher_feeds = sqlx::query_as::<_, Feed>(
            "SELECT id, owner_type::text as owner_type, owner_user_id, title, created_at FROM feeds WHERE owner_type = 'teacher' AND owner_user_id = $1"
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            eprintln!("Database error fetching teacher feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(teacher_feeds);
    }

    if claims.roles.iter().any(|role| role == "student") {
        let student_feeds = sqlx::query_as::<_, Feed>(
            r#"
            SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
            FROM feeds f
            JOIN teacher_student_relations tsr ON tsr.teacher_user_id = f.owner_user_id
            WHERE f.owner_type = 'teacher' AND tsr.student_user_id = $1
            "#
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            eprintln!("Database error fetching student feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(student_feeds);
    }

    if claims.roles.iter().any(|role| role == "parent") {
        let parent_feeds = sqlx::query_as::<_, Feed>(
            r#"
            SELECT DISTINCT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
            FROM feeds f
            JOIN parent_student_relations psr ON psr.parent_user_id = $1
            JOIN teacher_student_relations tsr ON tsr.student_user_id = psr.student_user_id
                AND tsr.teacher_user_id = f.owner_user_id
            WHERE f.owner_type = 'teacher'
            "#
        )
        .bind(user_id)
        .fetch_all(&app_state.db)
        .await
        .map_err(|e| {
            eprintln!("Database error fetching parent feeds: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch feeds")
        })?;
        feeds.extend(parent_feeds);
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
        "#
    )
    .bind(*feed_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed settings: {:?}", e);
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
        "#
    )
    .bind(*feed_id)
    .bind(payload.allow_student_posts)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error updating feed settings: {:?}", e);
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
        "#
    )
    .bind(*feed_id)
    .bind(user_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed user settings: {:?}", e);
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
        eprintln!("Database error updating feed user settings: {:?}", e);
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
            eprintln!("Database error fetching posts: {:?}", e);
            actix_web::error::ErrorInternalServerError("Failed to fetch posts")
        })?;

    Ok(HttpResponse::Ok().json(posts))
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
        eprintln!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    let feed = fetch_feed(&app_state, post.feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    Ok(HttpResponse::Ok().json(post))
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
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed for read mark: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark post as read")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    sqlx::query(
        r#"
        INSERT INTO feed_post_reads (post_id, user_id, read_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (post_id, user_id) DO UPDATE SET read_at = EXCLUDED.read_at
        "#
    )
    .bind(*post_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error marking post read: {:?}", e);
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
        "#
    )
    .bind(*feed_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error marking feed read: {:?}", e);
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
        "#
    )
    .bind(*feed_id)
    .fetch_one(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed settings: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch feed settings")
    })?;

    let is_teacher_owner = feed.owner_type == "teacher" && feed.owner_user_id == Some(user_id);
    let can_post = is_admin(&claims)
        || is_teacher_owner
        || (settings.allow_student_posts && claims.roles.iter().any(|role| role == "student"));

    if !can_post {
        return Err(actix_web::error::ErrorForbidden("Not allowed to post"));
    }

    let is_important = payload.is_important.unwrap_or(false);
    let allow_comments = payload.allow_comments.unwrap_or(true);

    let mut tx = app_state.db.begin().await.map_err(|e| {
        eprintln!("Database error starting transaction: {:?}", e);
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
        eprintln!("Database error creating post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create post")
    })?;

    sqlx::query(
        r#"
        INSERT INTO feed_post_reads (post_id, user_id, read_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (post_id, user_id) DO UPDATE SET read_at = EXCLUDED.read_at
        "#
    )
    .bind(post.id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        eprintln!("Database error marking post as read: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to mark post as read")
    })?;

    if let Some(media_ids) = &payload.media_ids {
        for (index, media_id) in media_ids.iter().enumerate() {
            sqlx::query(
                "INSERT INTO feed_post_media (post_id, media_id, sort_order) VALUES ($1, $2, $3)"
            )
            .bind(post.id)
            .bind(media_id)
            .bind(index as i32)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                eprintln!("Database error linking post media: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to attach media")
            })?;
        }
    }

    sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        VALUES ($1, $2, TRUE)
        ON CONFLICT (post_id, user_id) DO NOTHING
        "#
    )
    .bind(post.id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        eprintln!("Database error creating author subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create subscriptions")
    })?;

    sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        SELECT $1, fus.user_id, TRUE
        FROM feed_user_settings fus
        WHERE fus.feed_id = $2 AND fus.auto_subscribe_new_posts = TRUE
        ON CONFLICT (post_id, user_id) DO NOTHING
        "#
    )
    .bind(post.id)
    .bind(*feed_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        eprintln!("Database error auto-subscribing users: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create subscriptions")
    })?;

    tx.commit().await.map_err(|e| {
        eprintln!("Database error committing post: {:?}", e);
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

    Ok(HttpResponse::Created().json(post))
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
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed for comments: {:?}", e);
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
        eprintln!("Database error fetching comments: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch comments")
    })?;

    Ok(HttpResponse::Ok().json(comments))
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
        eprintln!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to fetch post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    if !post.allow_comments {
        return Err(actix_web::error::ErrorBadRequest("Comments are disabled for this post"));
    }

    let feed = fetch_feed(&app_state, post.feed_id).await?;
    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let mut tx = app_state.db.begin().await.map_err(|e| {
        eprintln!("Database error starting transaction: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create comment")
    })?;

    let comment = sqlx::query_as::<_, FeedComment>(
        r#"
        INSERT INTO feed_comments (post_id, author_user_id, parent_comment_id, content)
        VALUES ($1, $2, $3, $4)
        RETURNING id, post_id, author_user_id, parent_comment_id, content, created_at, updated_at
        "#
    )
    .bind(*post_id)
    .bind(user_id)
    .bind(payload.parent_comment_id)
    .bind(&payload.content)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| {
        eprintln!("Database error creating comment: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to create comment")
    })?;

    if let Some(media_ids) = &payload.media_ids {
        for (index, media_id) in media_ids.iter().enumerate() {
            sqlx::query(
                "INSERT INTO feed_comment_media (comment_id, media_id, sort_order) VALUES ($1, $2, $3)"
            )
            .bind(comment.id)
            .bind(media_id)
            .bind(index as i32)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                eprintln!("Database error linking comment media: {:?}", e);
                actix_web::error::ErrorInternalServerError("Failed to attach media")
            })?;
        }
    }

    sqlx::query(
        r#"
        INSERT INTO feed_post_subscriptions (post_id, user_id, notify_on_comments)
        VALUES ($1, $2, TRUE)
        ON CONFLICT (post_id, user_id) DO UPDATE SET notify_on_comments = TRUE
        "#
    )
    .bind(*post_id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        eprintln!("Database error creating comment subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to subscribe")
    })?;

    tx.commit().await.map_err(|e| {
        eprintln!("Database error committing comment: {:?}", e);
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

    Ok(HttpResponse::Created().json(comment))
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
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed for subscription: {:?}", e);
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
        "#
    )
    .bind(*post_id)
    .bind(user_id)
    .bind(payload.notify_on_comments)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error updating subscription: {:?}", e);
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
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed for subscription: {:?}", e);
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
        eprintln!("Database error fetching subscription: {:?}", e);
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
        SELECT f.id, f.owner_type::text as owner_type, f.owner_user_id, f.title, f.created_at
        FROM feeds f
        JOIN feed_posts p ON p.feed_id = f.id
        WHERE p.id = $1
        "#
    )
    .bind(*post_id)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error fetching feed for subscription removal: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to update subscription")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    ensure_feed_access(&app_state, &feed, user_id, &claims).await?;

    let result = sqlx::query(
        "DELETE FROM feed_post_subscriptions WHERE post_id = $1 AND user_id = $2"
    )
    .bind(*post_id)
    .bind(user_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error deleting subscription: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete subscription")
    })?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "deleted": result.rows_affected()
    })))
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
        eprintln!("Database error fetching post: {:?}", e);
        actix_web::error::ErrorInternalServerError("Failed to delete post")
    })?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Post not found"))?;

    // Check if user is admin or post author
    let is_admin = claims.roles.iter().any(|r| r == "admin");
    if !is_admin && post.author_user_id != user_id {
        return Err(actix_web::error::ErrorForbidden("You do not have permission to delete this post"));
    }

    // Delete the post (cascading deletes should handle comments and subscriptions)
    let result = sqlx::query(
        "DELETE FROM feed_posts WHERE id = $1"
    )
    .bind(*post_id)
    .execute(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error deleting post: {:?}", e);
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
            .route("/{feed_id}/user-settings", web::get().to(get_feed_user_settings))
            .route("/{feed_id}/user-settings", web::put().to(update_feed_user_settings))
            .route("/{feed_id}/posts", web::get().to(list_posts))
            .route("/{feed_id}/posts", web::post().to(create_post))
            .route("/{feed_id}/read", web::post().to(mark_feed_read))
            .route("/posts/{post_id}", web::get().to(get_post))
            .route("/posts/{post_id}", web::delete().to(delete_post))
            .route("/posts/{post_id}/read", web::post().to(mark_post_read))
            .route("/posts/{post_id}/comments", web::get().to(list_comments))
            .route("/posts/{post_id}/comments", web::post().to(create_comment))
            .route("/posts/{post_id}/subscribe", web::get().to(get_post_subscription))
            .route("/posts/{post_id}/subscribe", web::put().to(update_post_subscription))
            .route("/posts/{post_id}/subscribe", web::delete().to(delete_post_subscription))
    );
}
