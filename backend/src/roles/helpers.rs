use actix_web::{HttpRequest, HttpResponse};
use serde_json::json;

use crate::users::verify_token;
use crate::AppState;

pub fn verify_admin_role(req: &HttpRequest, app_state: &AppState) -> Result<(), HttpResponse> {
    let claims = verify_token(req, app_state)?;

    if !claims.roles.contains(&"admin".to_string()) {
        return Err(HttpResponse::Forbidden().json(json!({
            "error": "Admin access required"
        })));
    }

    Ok(())
}

pub async fn verify_can_edit_student(
    req: &HttpRequest,
    app_state: &AppState,
    student_user_id: i32,
) -> Result<(), HttpResponse> {
    let claims = verify_token(req, app_state)?;

    if claims.roles.contains(&"admin".to_string()) {
        return Ok(());
    }

    let user_result = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await;

    let current_user_id = match user_result {
        Ok(Some(id)) => id,
        _ => {
            return Err(HttpResponse::Unauthorized().json(json!({
                "error": "User not found"
            })))
        }
    };

    let relation_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM parent_student_relations psr
            JOIN parents p ON psr.parent_user_id = p.user_id
            WHERE psr.parent_user_id = $1 AND psr.student_user_id = $2 AND p.status = 'active'
        )"
    )
    .bind(current_user_id)
    .bind(student_user_id)
    .fetch_one(&app_state.db)
    .await;

    match relation_exists {
        Ok(true) => Ok(()),
        _ => Err(HttpResponse::Forbidden().json(json!({
            "error": "Not authorized to edit this student"
        }))),
    }
}

pub async fn verify_can_access_student(
    req: &HttpRequest,
    app_state: &AppState,
    student_user_id: i32,
) -> Result<i32, HttpResponse> {
    let claims = verify_token(req, app_state)?;

    let current_user_id = match sqlx::query_scalar::<_, i32>(
        "SELECT id FROM users WHERE username = $1"
    )
    .bind(&claims.sub)
    .fetch_optional(&app_state.db)
    .await
    {
        Ok(Some(id)) => id,
        _ => {
            return Err(HttpResponse::Unauthorized().json(json!({
                "error": "User not found"
            })));
        }
    };

    if claims.roles.contains(&"admin".to_string()) || current_user_id == student_user_id {
        return Ok(current_user_id);
    }

    let relation_exists = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(
            SELECT 1 FROM parent_student_relations psr
            JOIN parents p ON psr.parent_user_id = p.user_id
            WHERE psr.parent_user_id = $1 AND psr.student_user_id = $2 AND p.status = 'active'
        )"
    )
    .bind(current_user_id)
    .bind(student_user_id)
    .fetch_one(&app_state.db)
    .await;

    match relation_exists {
        Ok(true) => Ok(current_user_id),
        _ => {
            let teacher_relation_exists = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS(
                    SELECT 1 FROM teacher_student_relations tsr
                    JOIN teachers t ON tsr.teacher_user_id = t.user_id
                    WHERE tsr.teacher_user_id = $1 AND tsr.student_user_id = $2 AND t.status = 'active'
                )"
            )
            .bind(current_user_id)
            .bind(student_user_id)
            .fetch_one(&app_state.db)
            .await;

            match teacher_relation_exists {
                Ok(true) => Ok(current_user_id),
                _ => Err(HttpResponse::Forbidden().json(json!({
                    "error": "Not authorized to access this student"
                }))),
            }
        }
    }
}

pub async fn check_and_archive_parents(
    student_user_id: i32,
    archived_by_user_id: i32,
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
) -> Result<(), sqlx::Error> {
    let parent_ids: Vec<(i32,)> = sqlx::query_as(
        "SELECT parent_user_id FROM parent_student_relations WHERE student_user_id = $1"
    )
    .bind(student_user_id)
    .fetch_all(&mut **tx)
    .await?;

    for (parent_id,) in parent_ids {
        let has_active_students: (bool,) = sqlx::query_as(
            "SELECT EXISTS(
                SELECT 1 FROM parent_student_relations psr
                JOIN students s ON psr.student_user_id = s.user_id
                WHERE psr.parent_user_id = $1 AND s.status = 'active'
            )"
        )
        .bind(parent_id)
        .fetch_one(&mut **tx)
        .await?;

        if !has_active_students.0 {
            sqlx::query(
                "UPDATE parents SET status = 'archived', archived_at = NOW(), archived_by = $1 
                 WHERE user_id = $2"
            )
            .bind(archived_by_user_id)
            .bind(parent_id)
            .execute(&mut **tx)
            .await?;
        }
    }

    Ok(())
}

pub async fn check_and_unarchive_parents(
    student_user_id: i32,
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
) -> Result<(), sqlx::Error> {
    let parent_ids: Vec<(i32,)> = sqlx::query_as(
        "SELECT DISTINCT psr.parent_user_id 
         FROM parent_student_relations psr
         JOIN parents p ON psr.parent_user_id = p.user_id
         WHERE psr.student_user_id = $1 AND p.status = 'archived'"
    )
    .bind(student_user_id)
    .fetch_all(&mut **tx)
    .await?;

    for (parent_id,) in parent_ids {
        sqlx::query(
            "UPDATE parents SET status = 'active', archived_at = NULL, archived_by = NULL 
             WHERE user_id = $1"
        )
        .bind(parent_id)
        .execute(&mut **tx)
        .await?;
    }

    Ok(())
}
