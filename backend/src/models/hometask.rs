use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(sqlx::Type, Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "hometask_status", rename_all = "snake_case")]
pub enum HometaskStatus {
    Assigned,
    CompletedByStudent,
    AccomplishedByTeacher,
}

#[derive(sqlx::Type, Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "hometask_type", rename_all = "snake_case")]
pub enum HometaskType {
    Simple,
    Checklist,
    DailyRoutine,
    PhotoSubmission,
    TextSubmission,
}

#[derive(Serialize, Deserialize, Debug, Clone, FromRow)]
pub struct Hometask {
    pub id: i32,
    pub teacher_id: i32,
    pub student_id: i32,
    pub title: String,
    pub description: Option<String>,
    pub status: HometaskStatus,
    pub due_date: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sort_order: i32,
    pub hometask_type: HometaskType,
    pub content_id: Option<i32>,
}

#[derive(Serialize, Deserialize, Debug, Clone, FromRow)]
pub struct HometaskChecklist {
    pub id: i32,
    pub items: serde_json::Value,
}

#[derive(sqlx::Type, Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "submission_type", rename_all = "snake_case")]
pub enum SubmissionType {
    Photo,
    Text,
}

#[derive(Serialize, Deserialize, Debug, Clone, FromRow)]
pub struct HometaskSubmission {
    pub id: i32,
    pub hometask_id: i32,
    pub student_id: i32,
    pub submission_type: SubmissionType,
    pub content: String,
    pub created_at: DateTime<Utc>,
}
