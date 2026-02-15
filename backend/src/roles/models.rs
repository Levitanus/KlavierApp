use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Serialize, FromRow)]
pub struct Student {
    pub user_id: i32,
    pub full_name: String,
    pub birthday: NaiveDate,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow)]
pub struct Parent {
    pub user_id: i32,
    pub full_name: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, FromRow)]
pub struct Teacher {
    pub user_id: i32,
    pub full_name: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct StudentWithUserInfo {
    pub user_id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub birthday: NaiveDate,
    pub status: String,
}

#[derive(Debug, Serialize)]
pub struct ParentWithUserInfo {
    pub user_id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub children: Option<Vec<StudentWithUserInfo>>,
}

#[derive(Debug, Serialize)]
pub struct ParentSummary {
    pub user_id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub status: String,
}

#[derive(Debug, Serialize)]
pub struct TeacherWithUserInfo {
    pub user_id: i32,
    pub username: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub status: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateStudentRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub birthday: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateParentRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
    pub student_ids: Vec<i32>,
}

#[derive(Debug, Deserialize)]
pub struct CreateTeacherRequest {
    pub username: String,
    pub password: String,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub full_name: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateStudentRequest {
    pub full_name: Option<String>,
    pub birthday: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateParentRequest {
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTeacherRequest {
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct AddParentStudentRelationRequest {
    pub student_id: i32,
}

#[derive(Debug, Deserialize)]
pub struct AddTeacherStudentRelationRequest {
    pub student_id: i32,
}
