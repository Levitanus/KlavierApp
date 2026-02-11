use super::notifications::{NotificationBody, NotificationContent, ContentBlock, ActionButton};
use serde_json::json;

/// Helper functions to build common notification types

/// Create a password reset request notification for admins
pub fn build_password_reset_request_notification(
    username: &str,
    request_id: i32,
) -> NotificationBody {
    NotificationBody {
        body_type: "password_reset_request".to_string(),
        title: "Password Reset Request".to_string(),
        route: Some(format!("/admin/users/{}", username)),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("User **{}** has requested a password reset.", username),
                    style: Some("body".to_string()),
                },
                ContentBlock::Spacer { height: Some(8) },
                ContentBlock::Text {
                    text: "This user does not have an email address configured and requires admin assistance.".to_string(),
                    style: Some("caption".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "View User".to_string(),
                    route: Some(format!("/admin/users/{}", username)),
                    action: None,
                    primary: true,
                    icon: Some("person".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "request_id": request_id,
            "username": username,
        })),
    }
}

/// Create a task assignment notification for students
pub fn build_task_notification(
    task_id: i32,
    task_title: &str,
    teacher_name: &str,
    due_date: &str,
    description: Option<&str>,
    sheet_music_url: Option<&str>,
) -> NotificationBody {
    let mut blocks = vec![
        ContentBlock::Text {
            text: format!("{} assigned you a new task:", teacher_name),
            style: Some("body".to_string()),
        },
        ContentBlock::Text {
            text: task_title.to_string(),
            style: Some("title".to_string()),
        },
    ];
    
    if let Some(desc) = description {
        blocks.push(ContentBlock::Text {
            text: desc.to_string(),
            style: Some("body".to_string()),
        });
    }
    
    blocks.push(ContentBlock::Spacer { height: Some(8) });
    blocks.push(ContentBlock::Text {
        text: format!("📅 Due: {}", due_date),
        style: Some("caption".to_string()),
    });
    
    if let Some(url) = sheet_music_url {
        blocks.push(ContentBlock::Spacer { height: Some(12) });
        blocks.push(ContentBlock::Image {
            url: url.to_string(),
            alt: Some("Sheet music".to_string()),
            width: None,
            height: Some(200),
        });
    }
    
    NotificationBody {
        body_type: "task_assigned".to_string(),
        title: "New Homework Task".to_string(),
        route: Some(format!("/student/tasks/{}", task_id)),
        content: NotificationContent {
            blocks,
            actions: Some(vec![
                ActionButton {
                    label: "View Task".to_string(),
                    route: Some(format!("/student/tasks/{}", task_id)),
                    action: None,
                    primary: true,
                    icon: Some("task".to_string()),
                },
                ActionButton {
                    label: "Dismiss".to_string(),
                    route: None,
                    action: Some("dismiss".to_string()),
                    primary: false,
                    icon: None,
                },
            ]),
        },
        metadata: Some(json!({
            "task_id": task_id,
            "teacher_name": teacher_name,
        })),
    }
}

pub fn build_hometask_assigned_notification(
    hometask_id: i32,
    task_title: &str,
    teacher_name: &str,
    due_date: Option<&str>,
    student_id: i32,
) -> NotificationBody {
    let due_label = due_date.unwrap_or("No due date");

    NotificationBody {
        body_type: "hometask_assigned".to_string(),
        title: "New Hometask".to_string(),
        route: Some("/hometasks".to_string()),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("{} assigned a new hometask:", teacher_name),
                    style: Some("body".to_string()),
                },
                ContentBlock::Text {
                    text: task_title.to_string(),
                    style: Some("title".to_string()),
                },
                ContentBlock::Spacer { height: Some(8) },
                ContentBlock::Text {
                    text: format!("Due: {}", due_label),
                    style: Some("caption".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "View Hometasks".to_string(),
                    route: Some("/hometasks".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("task".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "hometask_id": hometask_id,
            "student_id": student_id,
            "teacher_name": teacher_name,
        })),
    }
}

pub fn build_hometask_accomplished_notification(
    hometask_id: i32,
    task_title: &str,
    teacher_name: &str,
    student_id: i32,
) -> NotificationBody {
    NotificationBody {
        body_type: "hometask_accomplished".to_string(),
        title: "Hometask Accomplished".to_string(),
        route: Some("/hometasks".to_string()),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("{} marked a hometask as accomplished:", teacher_name),
                    style: Some("body".to_string()),
                },
                ContentBlock::Text {
                    text: task_title.to_string(),
                    style: Some("title".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "View Hometasks".to_string(),
                    route: Some("/hometasks".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("task".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "hometask_id": hometask_id,
            "student_id": student_id,
            "teacher_name": teacher_name,
        })),
    }
}

pub fn build_hometask_completed_notification(
    hometask_id: i32,
    task_title: &str,
    student_name: &str,
    student_id: i32,
) -> NotificationBody {
    NotificationBody {
        body_type: "hometask_completed".to_string(),
        title: "Hometask Completed".to_string(),
        route: Some("/hometasks".to_string()),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("{} completed a hometask:", student_name),
                    style: Some("body".to_string()),
                },
                ContentBlock::Text {
                    text: task_title.to_string(),
                    style: Some("title".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "Review Hometasks".to_string(),
                    route: Some("/hometasks".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("task".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "hometask_id": hometask_id,
            "student_id": student_id,
            "student_name": student_name,
        })),
    }
}

pub fn build_hometask_reopened_notification(
    hometask_id: i32,
    task_title: &str,
    teacher_name: &str,
    student_id: i32,
) -> NotificationBody {
    NotificationBody {
        body_type: "hometask_reopened".to_string(),
        title: "Hometask Reopened".to_string(),
        route: Some("/hometasks".to_string()),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("{} marked a hometask as uncompleted:", teacher_name),
                    style: Some("body".to_string()),
                },
                ContentBlock::Text {
                    text: task_title.to_string(),
                    style: Some("title".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "View Hometasks".to_string(),
                    route: Some("/hometasks".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("task".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "hometask_id": hometask_id,
            "student_id": student_id,
            "teacher_name": teacher_name,
        })),
    }
}

pub fn build_hometask_refreshed_notification(
    hometask_id: i32,
    task_title: &str,
    teacher_name: &str,
    student_id: i32,
) -> NotificationBody {
    NotificationBody {
        body_type: "hometask_refreshed".to_string(),
        title: "Hometask Refreshed".to_string(),
        route: Some("/hometasks".to_string()),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("{} refreshed a repeating hometask:", teacher_name),
                    style: Some("body".to_string()),
                },
                ContentBlock::Text {
                    text: task_title.to_string(),
                    style: Some("title".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "View Hometasks".to_string(),
                    route: Some("/hometasks".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("task".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "hometask_id": hometask_id,
            "student_id": student_id,
            "teacher_name": teacher_name,
        })),
    }
}

/// Create a password issued notification for new users
pub fn build_password_issued_notification(
    admin_name: &str,
    temporary_password: &str,
) -> NotificationBody {
    NotificationBody {
        body_type: "password_issued".to_string(),
        title: "Your Account Password".to_string(),
        route: Some("/profile/change-password".to_string()),
        content: NotificationContent {
            blocks: vec![
                ContentBlock::Text {
                    text: format!("{} has created your account.", admin_name),
                    style: Some("body".to_string()),
                },
                ContentBlock::Spacer { height: Some(12) },
                ContentBlock::Text {
                    text: "Your temporary password is:".to_string(),
                    style: Some("caption".to_string()),
                },
                ContentBlock::Text {
                    text: temporary_password.to_string(),
                    style: Some("title".to_string()),
                },
                ContentBlock::Spacer { height: Some(12) },
                ContentBlock::Text {
                    text: "⚠️ Please change your password immediately after logging in.".to_string(),
                    style: Some("body".to_string()),
                },
            ],
            actions: Some(vec![
                ActionButton {
                    label: "Change Password".to_string(),
                    route: Some("/profile/change-password".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("lock".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "admin_name": admin_name,
            "requires_action": true,
        })),
    }
}

/// Create a schedule change notification for teachers
pub fn build_schedule_change_notification(
    lesson_date: &str,
    lesson_time: &str,
    student_name: &str,
    change_type: &str, // "rescheduled", "cancelled"
    reason: Option<&str>,
) -> NotificationBody {
    let title = match change_type {
        "cancelled" => "Lesson Cancelled",
        _ => "Lesson Rescheduled",
    };
    
    let mut blocks = vec![
        ContentBlock::Text {
            text: format!("Lesson with {} has been {}.", student_name, change_type),
            style: Some("body".to_string()),
        },
        ContentBlock::Spacer { height: Some(8) },
        ContentBlock::Text {
            text: format!("📅 Date: {}", lesson_date),
            style: Some("body".to_string()),
        },
        ContentBlock::Text {
            text: format!("🕐 Time: {}", lesson_time),
            style: Some("body".to_string()),
        },
    ];
    
    if let Some(r) = reason {
        blocks.push(ContentBlock::Spacer { height: Some(8) });
        blocks.push(ContentBlock::Divider);
        blocks.push(ContentBlock::Spacer { height: Some(8) });
        blocks.push(ContentBlock::Text {
            text: format!("Reason: {}", r),
            style: Some("caption".to_string()),
        });
    }
    
    NotificationBody {
        body_type: "schedule_change".to_string(),
        title: title.to_string(),
        route: Some("/teacher/schedule".to_string()),
        content: NotificationContent {
            blocks,
            actions: Some(vec![
                ActionButton {
                    label: "View Schedule".to_string(),
                    route: Some("/teacher/schedule".to_string()),
                    action: None,
                    primary: true,
                    icon: Some("calendar".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "student_name": student_name,
            "change_type": change_type,
        })),
    }
}

/// Create a results available notification for parents
pub fn build_results_notification(
    student_name: &str,
    assessment_title: &str,
    score: Option<f32>,
    teacher_comment: Option<&str>,
) -> NotificationBody {
    let mut blocks = vec![
        ContentBlock::Text {
            text: format!("New results available for {}", student_name),
            style: Some("body".to_string()),
        },
        ContentBlock::Spacer { height: Some(12) },
        ContentBlock::Text {
            text: assessment_title.to_string(),
            style: Some("title".to_string()),
        },
    ];
    
    if let Some(s) = score {
        blocks.push(ContentBlock::Spacer { height: Some(8) });
        blocks.push(ContentBlock::Text {
            text: format!("Score: {:.1}/100", s),
            style: Some("subtitle".to_string()),
        });
    }
    
    if let Some(comment) = teacher_comment {
        blocks.push(ContentBlock::Spacer { height: Some(12) });
        blocks.push(ContentBlock::Divider);
        blocks.push(ContentBlock::Spacer { height: Some(12) });
        blocks.push(ContentBlock::Text {
            text: "Teacher's comment:".to_string(),
            style: Some("caption".to_string()),
        });
        blocks.push(ContentBlock::Text {
            text: comment.to_string(),
            style: Some("body".to_string()),
        });
    }
    
    NotificationBody {
        body_type: "results_available".to_string(),
        title: "New Results Available".to_string(),
        route: Some(format!("/parent/student/{}/results", student_name)),
        content: NotificationContent {
            blocks,
            actions: Some(vec![
                ActionButton {
                    label: "View Details".to_string(),
                    route: Some(format!("/parent/student/{}/results", student_name)),
                    action: None,
                    primary: true,
                    icon: Some("assessment".to_string()),
                },
            ]),
        },
        metadata: Some(json!({
            "student_name": student_name,
            "assessment_title": assessment_title,
            "score": score,
        })),
    }
}

/// Create a generic announcement notification
pub fn build_announcement_notification(
    title: &str,
    message: &str,
    image_url: Option<&str>,
    link_label: Option<&str>,
    link_route: Option<&str>,
) -> NotificationBody {
    let mut blocks = vec![
        ContentBlock::Text {
            text: message.to_string(),
            style: Some("body".to_string()),
        },
    ];
    
    if let Some(url) = image_url {
        blocks.push(ContentBlock::Spacer { height: Some(12) });
        blocks.push(ContentBlock::Image {
            url: url.to_string(),
            alt: None,
            width: None,
            height: None,
        });
    }
    
    let actions = if let (Some(label), Some(route)) = (link_label, link_route) {
        Some(vec![
            ActionButton {
                label: label.to_string(),
                route: Some(route.to_string()),
                action: None,
                primary: true,
                icon: None,
            },
        ])
    } else {
        None
    };
    
    NotificationBody {
        body_type: "announcement".to_string(),
        title: title.to_string(),
        route: link_route.map(|s| s.to_string()),
        content: NotificationContent {
            blocks,
            actions,
        },
        metadata: None,
    }
}
