pub mod users;
pub mod admin;

use actix_web::{middleware, web, App};
use sqlx::postgres::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub db: PgPool,
    pub jwt_secret: String,
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
    App::new()
        .app_data(app_state)
        .wrap(middleware::Logger::default())
        .configure(users::configure)
        .configure(admin::configure)
}

pub async fn init_db(database_url: &str) -> Result<PgPool, sqlx::Error> {
    let pool = PgPool::connect(database_url).await?;
    
    // Run migrations
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await?;
    
    Ok(pool)
}
