use lettre::message::header::ContentType;
use lettre::transport::smtp::authentication::Credentials;
use lettre::{Message, SmtpTransport, Transport};
use std::env;

#[derive(Debug)]
pub enum EmailError {
    BuildError(String),
    SendError(String),
    ConfigError(String),
}

impl std::fmt::Display for EmailError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EmailError::BuildError(s) => write!(f, "Failed to build email: {}", s),
            EmailError::SendError(s) => write!(f, "Failed to send email: {}", s),
            EmailError::ConfigError(s) => write!(f, "Email configuration error: {}", s),
        }
    }
}

impl std::error::Error for EmailError {}

pub struct EmailService {
    from_email: String,
    smtp_host: String,
    smtp_username: String,
    smtp_password: String,
    reset_url_base: String,
}

impl EmailService {
    pub fn from_env() -> Result<Self, EmailError> {
        Ok(Self {
            from_email: env::var("FROM_EMAIL")
                .map_err(|_| EmailError::ConfigError("FROM_EMAIL not set".to_string()))?,
            smtp_host: env::var("SMTP_HOST")
                .map_err(|_| EmailError::ConfigError("SMTP_HOST not set".to_string()))?,
            smtp_username: env::var("SMTP_USERNAME")
                .map_err(|_| EmailError::ConfigError("SMTP_USERNAME not set".to_string()))?,
            smtp_password: env::var("SMTP_PASSWORD")
                .map_err(|_| EmailError::ConfigError("SMTP_PASSWORD not set".to_string()))?,
            reset_url_base: env::var("RESET_URL_BASE")
                .unwrap_or_else(|_| "http://localhost:8080/reset-password".to_string()),
        })
    }

    pub fn send_password_reset_email(
        &self,
        to_email: &str,
        username: &str,
        token: &str,
    ) -> Result<(), EmailError> {
        let reset_link = format!("{}/{}", self.reset_url_base, token);

        let body = format!(
            "Hello {},\n\n\
            You requested a password reset for your KlavierApp account.\n\n\
            Click the link below to reset your password:\n\
            {}\n\n\
            This link will expire in 1 hour.\n\n\
            If you didn't request this, please ignore this email.\n\n\
            Best regards,\n\
            KlavierApp Team",
            username, reset_link
        );

        let email = Message::builder()
            .from(
                self.from_email
                    .parse()
                    .map_err(|e| EmailError::BuildError(format!("Invalid from email: {}", e)))?,
            )
            .to(to_email
                .parse()
                .map_err(|e| EmailError::BuildError(format!("Invalid to email: {}", e)))?)
            .subject("Password Reset Request - KlavierApp")
            .header(ContentType::TEXT_PLAIN)
            .body(body)
            .map_err(|e| EmailError::BuildError(e.to_string()))?;

        let creds = Credentials::new(self.smtp_username.clone(), self.smtp_password.clone());

        let mailer = SmtpTransport::relay(&self.smtp_host)
            .map_err(|e| EmailError::SendError(format!("SMTP relay error: {}", e)))?
            .credentials(creds)
            .build();

        mailer
            .send(&email)
            .map_err(|e| EmailError::SendError(e.to_string()))?;

        Ok(())
    }

    pub fn send_admin_notification_email(
        &self,
        to_email: &str,
        username: &str,
    ) -> Result<(), EmailError> {
        let body = format!(
            "Hello Admin,\n\n\
            User '{}' has requested a password reset but has no email address on file.\n\n\
            Please check the admin panel to handle this request.\n\n\
            Best regards,\n\
            KlavierApp System",
            username
        );

        let email = Message::builder()
            .from(
                self.from_email
                    .parse()
                    .map_err(|e| EmailError::BuildError(format!("Invalid from email: {}", e)))?,
            )
            .to(to_email
                .parse()
                .map_err(|e| EmailError::BuildError(format!("Invalid to email: {}", e)))?)
            .subject("Password Reset Request Pending - KlavierApp")
            .header(ContentType::TEXT_PLAIN)
            .body(body)
            .map_err(|e| EmailError::BuildError(e.to_string()))?;

        let creds = Credentials::new(self.smtp_username.clone(), self.smtp_password.clone());

        let mailer = SmtpTransport::relay(&self.smtp_host)
            .map_err(|e| EmailError::SendError(format!("SMTP relay error: {}", e)))?
            .credentials(creds)
            .build();

        mailer
            .send(&email)
            .map_err(|e| EmailError::SendError(e.to_string()))?;

        Ok(())
    }
}
