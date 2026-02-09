use actix_web::{web, HttpServer};
use klavierapp_backend::{create_app, init_db, AppState};
use std::env;
use std::path::PathBuf;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
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

    // Create application state
    let app_state = web::Data::new(AppState {
        db: db_pool,
        jwt_secret,
    });

    println!("Starting server at http://127.0.0.1:8080");

    HttpServer::new(move || create_app(app_state.clone()))
        .bind(("127.0.0.1", 8080))?
        .run()
        .await
}
