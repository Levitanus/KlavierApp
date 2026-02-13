part of '../admin_panel.dart';

enum RoleStatus {
  active,
  archived;

  static RoleStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return RoleStatus.active;
      case 'archived':
        return RoleStatus.archived;
      default:
        return RoleStatus.active;
    }
  }
}

class User {
  final int id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final List<String> roles;
  final RoleStatus? studentStatus;
  final RoleStatus? parentStatus;
  final RoleStatus? teacherStatus;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.phone,
    required this.roles,
    this.studentStatus,
    this.parentStatus,
    this.teacherStatus,
  });

  RoleStatus? statusForRole(String role) {
    switch (role) {
      case 'student':
        return studentStatus;
      case 'parent':
        return parentStatus;
      case 'teacher':
        return teacherStatus;
      default:
        return null;
    }
  }

  bool isRoleArchived(String role) {
    return statusForRole(role) == RoleStatus.archived;
  }

  static RoleStatus? _parseRoleStatus(dynamic value) {
    if (value == null) {
      return null;
    }
    return RoleStatus.fromString(value.toString());
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      roles: List<String>.from(json['roles'] ?? []),
      studentStatus: _parseRoleStatus(json['student_status']),
      parentStatus: _parseRoleStatus(json['parent_status']),
      teacherStatus: _parseRoleStatus(json['teacher_status']),
    );
  }
}

class StudentInfo {
  final int userId;
  final String username;
  final String fullName;

  StudentInfo({
    required this.userId,
    required this.username,
    required this.fullName,
  });
}
