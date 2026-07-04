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
  const ChecklistItem({required this.text, required this.isDone, this.progress});

  final String text;
  final bool isDone;
  final int? progress;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      text: json['text'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson({required bool includeProgress}) {
    final payload = <String, dynamic>{'text': text};
    if (includeProgress) {
      payload['progress'] = progress ?? 0;
    } else {
      payload['is_done'] = isDone;
    }
    return payload;
  }
}

class Hometask {
  const Hometask({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
    required this.hometaskType,
    required this.checklistItems,
    required this.teacherName,
    this.description,
    this.dueDate,
    this.groupAssignmentId,
  });

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

  factory Hometask.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['checklist_items'] as List<dynamic>?;
    return Hometask(
      id: json['id'] as int,
      teacherId: json['teacher_id'] as int,
      teacherName: json['teacher_name'] as String?,
      studentId: json['student_id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: _parseStatus(json['status'] as String?),
      dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      hometaskType: _parseType(json['hometask_type'] as String?),
      checklistItems: itemsJson
              ?.whereType<Map<String, dynamic>>()
              .map(ChecklistItem.fromJson)
              .toList(growable: false) ??
          const <ChecklistItem>[],
      groupAssignmentId: (json['group_assignment_id'] as num?)?.toInt(),
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
  const StudentSummary({
    required this.userId,
    required this.username,
    required this.fullName,
  });

  final int userId;
  final String username;
  final String fullName;

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      userId: (json['user_id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['username'] as String? ?? '',
    );
  }
}

class StudentGroupSummary {
  const StudentGroupSummary({
    required this.id,
    required this.teacherUserId,
    required this.name,
    required this.students,
  });

  final int id;
  final int teacherUserId;
  final String name;
  final List<StudentSummary> students;

  factory StudentGroupSummary.fromJson(Map<String, dynamic> json) {
    final studentsRaw = json['students'] as List<dynamic>? ?? const [];
    return StudentGroupSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      teacherUserId: (json['teacher_user_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      students: studentsRaw
          .whereType<Map<String, dynamic>>()
          .map(StudentSummary.fromJson)
          .toList(growable: false),
    );
  }
}