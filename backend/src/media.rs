use actix_multipart::Multipart;
use actix_web::{post, web, HttpRequest, HttpResponse, Responder};
use futures_util::StreamExt as _;
use serde::Deserialize;

use crate::storage::{MediaError, MediaKind, MediaService};
use crate::users::verify_token;
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct MediaUploadQuery {
    #[serde(rename = "type")]
    pub media_type: String,
}

fn parse_media_kind(value: &str) -> Option<MediaKind> {
    match value {
        "image" => Some(MediaKind::Image),
        "audio" => Some(MediaKind::Audio),
        "video" => Some(MediaKind::Video),
        "file" => Some(MediaKind::File),
        _ => None,
    }
}

async fn extract_user_id_from_token(req: &HttpRequest, app_state: &AppState) -> Result<i32, HttpResponse> {
    let claims = match verify_token(req, app_state) {
        Ok(claims) => claims,
        Err(response) => return Err(response),
    };

    let user_id = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    .map_err(|e| {
        eprintln!("Database error getting user_id: {:?}", e);
        HttpResponse::InternalServerError().json(serde_json::json!({
            "error": "Failed to get user information"
        }))
    })?
    .ok_or_else(|| HttpResponse::Unauthorized().json(serde_json::json!({
        "error": "User not found"
    })))?;

    Ok(user_id)
}

/// Upload a media file for feeds/comments.
#[post("/upload")]
pub async fn upload_media(
    app_state: web::Data<AppState>,
    req: HttpRequest,
    payload: Multipart,
    query: web::Query<MediaUploadQuery>,
) -> impl Responder {
    let user_id = match extract_user_id_from_token(&req, &app_state).await {
        Ok(user_id) => user_id,
        Err(response) => return response,
    };

    let media_kind = match parse_media_kind(&query.media_type) {
        Some(kind) => kind,
        None => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Invalid media type. Use image, audio, video, or file."
            }))
        }
    };

    let mut payload = payload;

    while let Some(item) = payload.next().await {
        let field = match item {
            Ok(field) => field,
            Err(e) => {
                eprintln!("Multipart error: {}", e);
                return HttpResponse::BadRequest().json(serde_json::json!({
                    "error": "Failed to read upload"
                }));
            }
        };

        let content_disposition = field.content_disposition();
        if content_disposition.get_name() != Some("file") {
            continue;
        }

        let filename = content_disposition.get_filename().unwrap_or("upload.bin");
        let extension = std::path::Path::new(filename)
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("bin")
            .to_string();

        let mime_type = field
            .content_type()
            .map(|mime| mime.essence_str().to_string())
            .unwrap_or_else(|| "application/octet-stream".to_string());

        let media_service = MediaService::new(app_state.media_storage.clone());
        let stream = field.map(|chunk| {
            chunk.map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
        });

        let stored = match media_service
            .save_media_file(media_kind, &extension, stream)
            .await
        {
            Ok(stored) => stored,
            Err(MediaError::InvalidFileType) => {
                return HttpResponse::BadRequest().json(serde_json::json!({
                    "error": "Invalid file type for this media category."
                }))
            }
            Err(MediaError::TooLarge) => {
                return HttpResponse::BadRequest().json(serde_json::json!({
                    "error": "File too large."
                }))
            }
            Err(MediaError::Io(e)) => {
                eprintln!("Failed to save file: {}", e);
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to save file"
                }));
            }
        };

        let media_id: i32 = match sqlx::query_scalar(
            r#"
            INSERT INTO media_files (storage_key, public_url, media_type, mime_type, size_bytes, created_by_user_id)
            VALUES ($1, $2, $3::media_type, $4, $5, $6)
            RETURNING id
            "#
        )
        .bind(&stored.key)
        .bind(&stored.url)
        .bind(match media_kind {
            MediaKind::Image => "image",
            MediaKind::Audio => "audio",
            MediaKind::Video => "video",
            MediaKind::File => "file",
        })
        .bind(&mime_type)
        .bind(stored.size_bytes as i32)
        .bind(user_id)
        .fetch_one(&app_state.db)
        .await
        {
            Ok(id) => id,
            Err(e) => {
                eprintln!("Database error saving media record: {:?}", e);
                return HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Failed to save media record"
                }));
            }
        };

        return HttpResponse::Ok().json(serde_json::json!({
            "id": media_id,
            "key": stored.key,
            "url": stored.url,
            "mime_type": mime_type,
            "size_bytes": stored.size_bytes
        }));
    }

    HttpResponse::BadRequest().json(serde_json::json!({
        "error": "No file uploaded"
    }))
}

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api/media")
            .service(upload_media)
    );
}
