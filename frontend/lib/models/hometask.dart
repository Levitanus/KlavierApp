enum HometaskStatus { assigned, completedByStudent, accomplishedByTeacher }

enum HometaskType {
  simple,
  checklist,
  progress,
  freeAnswer,
  dailyRoutine,
  photoSubmission,
  textSubmission,
}

class ChecklistItem {
  final String text;
  final bool isDone;
  final int? progress;

  ChecklistItem({required this.text, required this.isDone, this.progress});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      text: json['text'] ?? '',
      isDone: json['is_done'] ?? false,
      progress: json['progress'] as int?,
    );
  }
}

class Hometask {
  final int id;
  final int teacherId;
  final String? teacherName;
  final int studentId;
  final String title;
  final String? description;
  final HometaskStatus status;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;
  final HometaskType hometaskType;
  final List<ChecklistItem> checklistItems;
  final int? groupAssignmentId;

  Hometask({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.studentId,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
    required this.hometaskType,
    required this.checklistItems,
    required this.groupAssignmentId,
  });

  factory Hometask.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['checklist_items'] as List<dynamic>?;
    return Hometask(
      id: json['id'],
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'],
      studentId: json['student_id'],
      title: json['title'] ?? '',
      description: json['description'],
      status: _parseStatus(json['status']),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sortOrder: json['sort_order'] ?? 0,
      hometaskType: _parseType(json['hometask_type']),
      checklistItems:
          itemsJson?.map((item) => ChecklistItem.fromJson(item)).toList() ?? [],
      groupAssignmentId: json['group_assignment_id'] as int?,
    );
  }

  Hometask copyWith({
    List<ChecklistItem>? checklistItems,
    HometaskStatus? status,
  }) {
    return Hometask(
      id: id,
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      title: title,
      description: description,
      status: status ?? this.status,
      dueDate: dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sortOrder: sortOrder,
      hometaskType: hometaskType,
      checklistItems: checklistItems ?? this.checklistItems,
      groupAssignmentId: groupAssignmentId,
    );
  }

  static HometaskStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed_by_student':
        return HometaskStatus.completedByStudent;
      case 'accomplished_by_teacher':
        return HometaskStatus.accomplishedByTeacher;
      case 'assigned':
      default:
        return HometaskStatus.assigned;
    }
  }

  static HometaskType _parseType(String? type) {
    switch (type) {
      case 'simple':
        return HometaskType.simple;
      case 'free_answer':
        return HometaskType.freeAnswer;
      case 'daily_routine':
        return HometaskType.dailyRoutine;
      case 'photo_submission':
        return HometaskType.photoSubmission;
      case 'text_submission':
        return HometaskType.textSubmission;
      case 'progress':
        return HometaskType.progress;
      case 'checklist':
      default:
        return HometaskType.checklist;
    }
  }
}

class StudentSummary {
  final int userId;
  final String username;
  final String fullName;

  StudentSummary({
    required this.userId,
    required this.username,
    required this.fullName,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      userId: json['user_id'] ?? json['id'],
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? json['username'] ?? '',
    );
  }
}
