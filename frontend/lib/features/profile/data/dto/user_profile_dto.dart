import '../../domain/entities/user_profile.dart';

class UserProfileDto {
  const UserProfileDto({
    required this.id,
    required this.username,
    required this.fullName,
    required this.createdAtSeconds,
    required this.roles,
    this.email,
    this.phone,
    this.profileImage,
    this.studentData,
    this.parentData,
    this.teacherData,
  });

  final int id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? profileImage;
  final int createdAtSeconds;
  final List<String> roles;
  final StudentProfileDataDto? studentData;
  final ParentProfileDataDto? parentData;
  final TeacherProfileDataDto? teacherData;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    return UserProfileDto(
      id: _parseInt(json['id']) ?? 0,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      profileImage: json['profile_image'] as String?,
      createdAtSeconds: _parseInt(json['created_at']) ?? 0,
      roles: _parseRoles(json['roles']),
      studentData: _parseMap(json['student_data']) == null
          ? null
          : StudentProfileDataDto.fromJson(_parseMap(json['student_data'])!),
      parentData: _parseMap(json['parent_data']) == null
          ? null
          : ParentProfileDataDto.fromJson(_parseMap(json['parent_data'])!),
      teacherData: _parseMap(json['teacher_data']) == null
          ? null
          : TeacherProfileDataDto.fromJson(_parseMap(json['teacher_data'])!),
    );
  }

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      username: username,
      fullName: fullName,
      email: email,
      phone: phone,
      profileImage: profileImage,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000, isUtc: true),
      roles: roles,
      studentData: studentData?.toDomain(),
      parentData: parentData?.toDomain(),
      teacherData: teacherData?.toDomain(),
    );
  }
}

class StudentProfileDataDto {
  const StudentProfileDataDto({
    required this.fullName,
    required this.birthday,
    required this.status,
  });

  final String fullName;
  final DateTime birthday;
  final String status;

  factory StudentProfileDataDto.fromJson(Map<String, dynamic> json) {
    return StudentProfileDataDto(
      fullName: json['full_name'] as String? ?? '',
      birthday: DateTime.parse(json['birthday'] as String),
      status: json['status'] as String? ?? '',
    );
  }

  StudentProfileData toDomain() {
    return StudentProfileData(
      fullName: fullName,
      birthday: birthday,
      status: status,
    );
  }
}

class StudentChildInfoDto {
  const StudentChildInfoDto({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.birthday,
    required this.status,
    this.profileImage,
  });

  final int userId;
  final String username;
  final String fullName;
  final DateTime birthday;
  final String status;
  final String? profileImage;

  factory StudentChildInfoDto.fromJson(Map<String, dynamic> json) {
    return StudentChildInfoDto(
      userId: _parseInt(json['user_id']) ?? 0,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      birthday: DateTime.parse(json['birthday'] as String),
      status: json['status'] as String? ?? '',
      profileImage: json['profile_image'] as String?,
    );
  }

  StudentChildInfo toDomain() {
    return StudentChildInfo(
      userId: userId,
      username: username,
      fullName: fullName,
      birthday: birthday,
      status: status,
      profileImage: profileImage,
    );
  }
}

class ParentProfileDataDto {
  const ParentProfileDataDto({
    required this.fullName,
    required this.status,
    required this.children,
  });

  final String fullName;
  final String status;
  final List<StudentChildInfoDto> children;

  factory ParentProfileDataDto.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return ParentProfileDataDto(
      fullName: json['full_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      children: rawChildren is List
          ? rawChildren
                .whereType<Map<String, dynamic>>()
                .map(StudentChildInfoDto.fromJson)
                .toList(growable: false)
          : const <StudentChildInfoDto>[],
    );
  }

  ParentProfileData toDomain() {
    return ParentProfileData(
      fullName: fullName,
      status: status,
      children: children.map((child) => child.toDomain()).toList(growable: false),
    );
  }
}

class TeacherProfileDataDto {
  const TeacherProfileDataDto({
    required this.fullName,
    required this.status,
  });

  final String fullName;
  final String status;

  factory TeacherProfileDataDto.fromJson(Map<String, dynamic> json) {
    return TeacherProfileDataDto(
      fullName: json['full_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  TeacherProfileData toDomain() {
    return TeacherProfileData(fullName: fullName, status: status);
  }
}

int? _parseInt(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw);
  }
  return null;
}

List<String> _parseRoles(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return raw.whereType<String>().toList(growable: false);
}

Map<String, dynamic>? _parseMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  return null;
}
