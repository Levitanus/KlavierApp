use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use chrono::{DateTime, Duration, Utc};
use rand::{distributions::Alphanumeric, Rng};
use sqlx::{FromRow, PgPool};
use std::sync::Arc;

use actix_web::rt::task::spawn_blocking;
use log::error;

use crate::email::{EmailError, EmailService};
use crate::notification_builders::build_password_reset_request_notification;
use crate::push;

#[derive(Debug)]
pub enum PasswordResetError {
    DatabaseError(String),
    TokenNotFound,
    TokenExpired,
    TokenAlreadyUsed,
    UserNotFound,
    HashError(String),
    EmailError(EmailError),
}

impl std::fmt::Display for PasswordResetError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            PasswordResetError::DatabaseError(s) => write!(f, "Database error: {}", s),
            PasswordResetError::TokenNotFound => write!(f, "Invalid or expired reset token"),
            PasswordResetError::TokenExpired => write!(f, "Reset token has expired"),
            PasswordResetError::TokenAlreadyUsed => write!(f, "Reset token has already been used"),
            PasswordResetError::UserNotFound => write!(f, "User not found"),
            PasswordResetError::HashError(s) => write!(f, "Hashing error: {}", s),
            PasswordResetError::EmailError(e) => write!(f, "Email error: {}", e),
        }
    }
}

impl std::error::Error for PasswordResetError {}

impl From<sqlx::Error> for PasswordResetError {
    fn from(err: sqlx::Error) -> Self {
        PasswordResetError::DatabaseError(err.to_string())
    }
}

impl From<EmailError> for PasswordResetError {
    fn from(err: EmailError) -> Self {
        PasswordResetError::EmailError(err)
    }
}

#[derive(Debug, FromRow)]
pub struct PasswordResetToken {
    pub id: i32,
    pub user_id: i32,
    pub token_hash: String,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub used_at: Option<DateTime<Utc>>,
}

#[derive(Debug, FromRow)]
pub struct PasswordResetRequest {
    pub id: i32,
    pub username: String,
    pub requested_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
    pub resolved_by_admin_id: Option<i32>,
}

/// Generate a secure random token (32 characters, URL-safe)
pub fn generate_token() -> String {
    rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .take(32)
        .map(char::from)
        .collect()
}

/// Hash a token using Argon2
pub fn hash_token(token: &str) -> Result<String, PasswordResetError> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    
    argon2
        .hash_password(token.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|e| PasswordResetError::HashError(e.to_string()))
}

/// Verify a token against a hash
pub fn verify_token(token: &str, hash: &str) -> Result<bool, PasswordResetError> {
    let parsed_hash = PasswordHash::new(hash)
        .map_err(|e| PasswordResetError::HashError(e.to_string()))?;
    
    Ok(Argon2::default()
        .verify_password(token.as_bytes(), &parsed_hash)
        .is_ok())
}

/// Request a password reset for a user by username
pub async fn request_password_reset(
    pool: &PgPool,
    username: &str,
    email_service: Arc<EmailService>,
) -> Result<(), PasswordResetError> {
    // Find user by username
    #[derive(FromRow)]
    struct UserQuery {
        id: i32,
        username: String,
        email: Option<String>,
    }
    
    let user = sqlx::query_as::<_, UserQuery>(
        "SELECT id, username, email FROM users WHERE username = $1"
    )
    .bind(username)
    .fetch_optional(pool)
    .await?
    .ok_or(PasswordResetError::UserNotFound)?;

    if let Some(email) = user.email {
        // User has email - generate token and send email
        let token = generate_token();
        let token_hash = hash_token(&token)?;
        let expires_at = Utc::now() + Duration::hours(1);

        // Save token to database
        sqlx::query(
            "INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) 
             VALUES ($1, $2, $3)"
        )
        .bind(user.id)
        .bind(token_hash)
        .bind(expires_at)
        .execute(pool)
        .await?;

        // Send email in the background to avoid blocking the response.
        let email_service = email_service.clone();
        let username = user.username.clone();
        let token = token.clone();
        spawn_blocking(move || {
            if let Err(err) = email_service.send_password_reset_email(&email, &username, &token) {
                error!("Password reset email failed: {}", err);
            }
        });
    } else {
        // User has no email - create a request for admin
        let request_id = sqlx::query_scalar::<_, i32>(
            "INSERT INTO password_reset_requests (username) VALUES ($1) RETURNING id"
        )
        .bind(username)
        .fetch_one(pool)
        .await?;
        
        // Get all admin user IDs
        let admin_ids = get_admin_user_ids(pool).await?;
        
        // Create notification for each admin
        let notification_body = build_password_reset_request_notification(username, request_id);
        
        for admin_id in admin_ids {
            let notification_id = sqlx::query_scalar::<_, i32>(
                "INSERT INTO notifications (user_id, type, title, body, priority)
                 VALUES ($1, $2, $3, $4, $5)
                 RETURNING id"
            )
            .bind(admin_id)
            .bind(&notification_body.body_type)
            .bind(&notification_body.title)
            .bind(serde_json::to_value(&notification_body).unwrap_or_default())
            .bind("high") // High priority for admin action items
            .fetch_optional(pool)
            .await
            .unwrap_or(None);

            if let Some(notification_id) = notification_id {
                push::send_notification_to_user(pool, admin_id, &notification_body, Some(notification_id)).await;
            }
        }
    }

    Ok(())
}

/// Verify a reset token and return the associated user_id if valid
pub async fn verify_reset_token(
    pool: &PgPool,
    token: &str,
) -> Result<(i32, i32), PasswordResetError> {
    // Get all non-expired, non-used tokens
    let tokens = sqlx::query_as::<_, PasswordResetToken>(
        "SELECT id, user_id, token_hash, created_at, expires_at, used_at 
         FROM password_reset_tokens 
         WHERE used_at IS NULL AND expires_at > NOW()"
    )
    .fetch_all(pool)
    .await?;

    // Check each token hash
    for token_record in tokens {
        if verify_token(token, &token_record.token_hash)? {
            // Token matches and is valid
            return Ok((token_record.id, token_record.user_id));
        }
    }

    Err(PasswordResetError::TokenNotFound)
}

/// Reset password using a valid token
pub async fn reset_password_with_token(
    pool: &PgPool,
    token: &str,
    new_password: &str,
) -> Result<(), PasswordResetError> {
    // Verify token and get user_id
    let (token_id, user_id) = verify_reset_token(pool, token).await?;

    // Hash the new password
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = argon2
        .hash_password(new_password.as_bytes(), &salt)
        .map_err(|e| PasswordResetError::HashError(e.to_string()))?
        .to_string();

    // Update user password
    sqlx::query(
        "UPDATE users SET password_hash = $1 WHERE id = $2"
    )
    .bind(password_hash)
    .bind(user_id)
    .execute(pool)
    .await?;

    // Mark token as used
    sqlx::query(
        "UPDATE password_reset_tokens SET used_at = NOW() WHERE id = $1"
    )
    .bind(token_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Generate a reset token for a user (admin function)
pub async fn generate_reset_token_for_user(
    pool: &PgPool,
    user_id: i32,
) -> Result<String, PasswordResetError> {
    let token = generate_token();
    let token_hash = hash_token(&token)?;
    let expires_at = Utc::now() + Duration::hours(1);

    sqlx::query(
        "INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) 
         VALUES ($1, $2, $3)"
    )
    .bind(user_id)
    .bind(token_hash)
    .bind(expires_at)
    .execute(pool)
    .await?;

    Ok(token)
}

/// Get all pending password reset requests (admin function)
pub async fn get_pending_requests(pool: &PgPool) -> Result<Vec<PasswordResetRequest>, PasswordResetError> {
    let requests = sqlx::query_as::<_, PasswordResetRequest>(
        "SELECT id, username, requested_at, resolved_at, resolved_by_admin_id 
         FROM password_reset_requests 
         WHERE resolved_at IS NULL 
         ORDER BY requested_at DESC"
    )
    .fetch_all(pool)
    .await?;

    Ok(requests)
}

/// Mark a password reset request as resolved (admin function)
pub async fn resolve_request(
    pool: &PgPool,
    request_id: i32,
    admin_id: i32,
) -> Result<(), PasswordResetError> {
    sqlx::query(
        "UPDATE password_reset_requests 
         SET resolved_at = NOW(), resolved_by_admin_id = $1 
         WHERE id = $2"
    )
    .bind(admin_id)
    .bind(request_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Cleanup expired tokens (maintenance function)
pub async fn cleanup_expired_tokens(pool: &PgPool) -> Result<u64, PasswordResetError> {
    let result = sqlx::query(
        "DELETE FROM password_reset_tokens 
         WHERE expires_at < NOW() - INTERVAL '24 hours'"
    )
    .execute(pool)
    .await?;

    Ok(result.rows_affected())
}

/// Get all user IDs that have the 'admin' role
async fn get_admin_user_ids(pool: &PgPool) -> Result<Vec<i32>, PasswordResetError> {
    let admin_ids = sqlx::query_scalar::<_, i32>(
        "SELECT u.id FROM users u
         INNER JOIN user_roles ur ON u.id = ur.user_id
         INNER JOIN roles r ON ur.role_id = r.id
         WHERE r.name = 'admin'"
    )
    .fetch_all(pool)
    .await?;
    
    Ok(admin_ids)
}
