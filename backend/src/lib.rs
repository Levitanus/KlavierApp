pub mod users;
pub mod admin;
pub mod email;
pub mod password_reset;

use actix_web::{middleware, web, App};
use actix_files as fs;
use actix_cors::Cors;
use sqlx::postgres::PgPool;
use std::sync::Arc;
use std::path::PathBuf;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_secret: String,
    pub email_service: Arc<email::EmailService>,
    pub upload_dir: PathBuf,
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
    let profile_images_dir = app_state.upload_dir.clone();
    
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
        .wrap(middleware::Logger::default())
        .configure(users::configure)
        .configure(admin::configure)
        .service(fs::Files::new("/uploads/profile_images", profile_images_dir).show_files_listing())
}

pub async fn init_db(database_url: &str) -> Result<PgPool, sqlx::Error> {
    let pool = PgPool::connect(database_url).await?;
    
    // Run migrations
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await?;
    
    Ok(pool)
}
