use log::{debug};
pub mod users;
pub mod admin;
pub mod email;
pub mod password_reset;
pub mod notifications;
pub mod notification_builders;
pub mod roles;
pub mod registration_tokens;
pub mod hometasks;
pub mod models;
pub mod storage;
pub mod feeds;
pub mod media;
pub mod chats;
pub mod websockets;
pub mod push;

use actix_web::{middleware, web, App};
use actix_files as fs;
use actix_cors::Cors;
use actix_web_actors::ws;
use serde::Deserialize;
use sqlx::postgres::PgPool;
use std::sync::Arc;
use std::path::PathBuf;
use storage::StorageProvider;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_secret: String,
    pub email_service: Arc<email::EmailService>,
    pub storage: Arc<dyn StorageProvider>,
    pub profile_images_dir: PathBuf,
    pub media_storage: Arc<dyn StorageProvider>,
    pub media_dir: PathBuf,
    pub ws_server: websockets::WsServerActor,
}

async fn ws_endpoint(
    req: actix_web::HttpRequest,
    stream: web::Payload,
    app_state: web::Data<AppState>,
) -> Result<actix_web::HttpResponse, actix_web::Error> {
    #[derive(Deserialize)]
    struct WsQuery {
        token: Option<String>,
    }

    // Extract user_id from JWT token
    let mut token: Option<String> = None;

    if let Some(auth_header) = req.headers().get("Authorization") {
        if let Ok(auth_str) = auth_header.to_str() {
            if let Some(value) = auth_str.strip_prefix("Bearer ") {
                token = Some(value.to_string());
            }
        }
    }

    if token.is_none() {
        if let Ok(query) = web::Query::<WsQuery>::from_query(req.query_string()) {
            token = query.into_inner().token;
        }
    }

    if let Some(token) = token {
        // Verify token and get user_id
        use jsonwebtoken::{decode, DecodingKey, Validation};
        let decoding_key = DecodingKey::from_secret(app_state.jwt_secret.as_bytes());
        
        if let Ok(token_data) = decode::<users::Claims>(
            &token,
            &decoding_key,
            &Validation::default(),
        ) {
            // Query database to get user_id from username
            let username = &token_data.claims.sub;
            match sqlx::query_scalar::<_, i32>(
                "SELECT id FROM users WHERE username = $1"
            )
            .bind(username)
            .fetch_optional(&app_state.db)
            .await
            {
                Ok(Some(user_id)) => {
                    debug!("[ws] authenticated user {}", user_id);
                    let ws_session = websockets::WsSession {
                        user_id,
                        server: app_state.ws_server.clone(),
                    };
                    
                    return ws::start(ws_session, &req, stream);
                }
                _ => {
                    debug!("[ws] user not found for username {}", username);
                    return Err(actix_web::error::ErrorNotFound("User not found"));
                }
            }
        }
    }
    
    debug!("[ws] missing or invalid token");
    Err(actix_web::error::ErrorUnauthorized("Missing or invalid token"))
}

pub fn create_app(app_state: web::Data<AppState>) -> App<
    impl actix_web::dev::ServiceFactory<
        actix_web::dev::ServiceRequest,
        Config = (),
        Response = actix_web::dev::ServiceResponse<impl actix_web::body::MessageBody>,
        Error = actix_web::Error,
        InitError = (),
    >,
> {
    let profile_images_dir = app_state.profile_images_dir.clone();
    let media_dir = app_state.media_dir.clone();
    
    debug!("=== Creating App ===");
    
    App::new()
        .app_data(app_state)
        .app_data(web::PayloadConfig::new(10 * 1024 * 1024)) // 10MB max payload
        .wrap(
            Cors::default()
                .allow_any_origin()
                .allow_any_method()
                .allow_any_header()
                .max_age(3600)
        )
        .wrap(middleware::Logger::new("%a %{User-Agent}i %r %s %b %Dms"))
        .configure(users::configure)
        .configure(admin::configure)
        .configure(notifications::configure)
        .configure(roles::configure_routes)
        .configure(registration_tokens::configure_routes)
        .configure(hometasks::init_routes)
        .configure(feeds::configure)
        .configure(media::configure)
        .configure(chats::configure)
        .configure(push::configure)
        .route("/ws", web::get().to(ws_endpoint))
        .service(fs::Files::new("/uploads/profile_images", profile_images_dir).show_files_listing())
        .service(fs::Files::new("/uploads/media", media_dir).show_files_listing())
}

pub async fn init_db(database_url: &str) -> Result<PgPool, sqlx::Error> {
    let pool = PgPool::connect(database_url).await?;
    
    // Run migrations
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await?;
    
    Ok(pool)
}
