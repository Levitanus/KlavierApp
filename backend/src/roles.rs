use actix_web::web;

mod helpers;
mod models;
mod parent;
mod student;
mod teacher;

pub use models::*;
pub use parent::*;
pub use student::*;
pub use teacher::*;

pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg
        // Student routes
        .service(create_student)
        .service(list_students)
        .service(get_student)
        .service(update_student)
        .service(archive_student_role)
        .service(unarchive_student_role)
        .service(list_student_teachers)
        .service(remove_student_teacher_relation)
        .service(list_student_parents)
        // Parent routes
        .service(create_parent)
        .service(get_parent)
        .service(update_parent)
        .service(add_parent_student_relation)
        .service(remove_parent_student_relation)
        .service(archive_parent_role)
        .service(unarchive_parent_role)
        // Teacher routes
        .service(create_teacher)
        .service(get_teacher)
        .service(update_teacher)
        .service(list_teacher_students)
        .service(add_teacher_student_relation)
        .service(remove_teacher_student_relation)
        .service(archive_teacher_role)
        .service(unarchive_teacher_role);
}
