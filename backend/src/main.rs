use actix_web::{web, HttpServer};
use klavierapp_backend::{create_app, init_db, AppState, email::EmailService, websockets};
use klavierapp_backend::storage::LocalStorage;
use std::env;
use std::path::PathBuf;
use std::sync::Arc;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logger
    env_logger::init();
    
    // Load environment variables from .env file in project root
    let env_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join(".env");
    
    dotenv::from_path(&env_path)
        .map_err(|e| std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("Failed to load .env file from {:?}: {}", env_path, e)
        ))?;

    // Get configuration from environment - fail if not set
    let database_url = env::var("DATABASE_URL")
        .map_err(|_| std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "DATABASE_URL environment variable is required"
        ))?;
    
    let jwt_secret = env::var("JWT_SECRET")
        .map_err(|_| std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "JWT_SECRET environment variable is required"
        ))?;

    // Initialize database
    let db_pool = init_db(&database_url)
        .await
        .map_err(|e| std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to initialize database: {}", e)
        ))?;

    println!("Database initialized successfully");

    // Initialize email service
    let email_service = EmailService::from_env()
        .map(Arc::new)
        .unwrap_or_else(|e| {
            println!("Warning: Email service not configured: {}", e);
            println!("Password reset emails will not be sent. Set SMTP environment variables to enable email.");
            // For development, we'll create a dummy service with empty values
            // In production, you should ensure proper email configuration
            std::env::set_var("FROM_EMAIL", "noreply@example.com");
            std::env::set_var("SMTP_HOST", "localhost");
            std::env::set_var("SMTP_USERNAME", "user");
            std::env::set_var("SMTP_PASSWORD", "pass");
            Arc::new(EmailService::from_env().expect("Failed to create fallback email service"))
        });

    // Create upload directory
    let upload_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("uploads");
    
    let profile_images_dir = upload_dir.join("profile_images");
    let media_dir = upload_dir.join("media");
    
    std::fs::create_dir_all(&profile_images_dir)
        .map_err(|e| std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to create upload directory: {}", e)
        ))?;

    std::fs::create_dir_all(&media_dir)
        .map_err(|e| std::io::Error::new(
            std::io::ErrorKind::Other,
            format!("Failed to create media directory: {}", e)
        ))?;
    
    println!("Upload directory: {:?}", profile_images_dir);

    let storage = Arc::new(LocalStorage::new(
        profile_images_dir.clone(),
        "/uploads/profile_images".to_string(),
    ));

    let media_storage = Arc::new(LocalStorage::new(
        media_dir.clone(),
        "/uploads/media".to_string(),
    ));

    // Create application state
    let app_state = web::Data::new(AppState {
        db: db_pool,
        jwt_secret,
        email_service,
        storage,
        profile_images_dir,
        media_storage,
        media_dir,
        ws_server: websockets::WsServerActor::new(),
    });

    println!("Starting server at http://127.0.0.1:8080");

    HttpServer::new(move || create_app(app_state.clone()))
        .bind(("127.0.0.1", 8080))?
        .run()
        .await
}
