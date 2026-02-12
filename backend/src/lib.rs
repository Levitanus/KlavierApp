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

use actix_web::{middleware, web, App};
use actix_files as fs;
use actix_cors::Cors;
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
    
    println!("=== Creating App ===");
    
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
