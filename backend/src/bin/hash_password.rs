use log::{error, info};
use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Argon2,
};
use rand_core::OsRng;
use std::env;

fn main() {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info"),
    )
    .init();
    let args: Vec<String> = env::args().collect();
    
    if args.len() != 2 {
        error!("Usage: {} <password>", args[0]);
        std::process::exit(1);
    }
    
    let password = &args[1];
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    
    let password_hash = argon2
        .hash_password(password.as_bytes(), &salt)
        .expect("Failed to hash password");
    
    info!("{}", password_hash);
}
