import '../../domain/entities/registration_token_info.dart';

class RegistrationTokenInfoDto {
  const RegistrationTokenInfoDto({
    required this.valid,
    this.role,
    this.relatedStudent,
    this.relatedTeacher,
  });

  final bool valid;
  final String? role;
  final RegistrationPersonInfoDto? relatedStudent;
  final RegistrationPersonInfoDto? relatedTeacher;

  factory RegistrationTokenInfoDto.fromJson(Map<String, dynamic> json) {
    return RegistrationTokenInfoDto(
      valid: json['valid'] == true,
      role: json['role'] as String?,
      relatedStudent: _parseMap(json['related_student']) == null
          ? null
          : RegistrationPersonInfoDto.fromJson(_parseMap(json['related_student'])!),
      relatedTeacher: _parseMap(json['related_teacher']) == null
          ? null
          : RegistrationPersonInfoDto.fromJson(_parseMap(json['related_teacher'])!),
    );
  }

  RegistrationTokenInfo toDomain() {
    return RegistrationTokenInfo(
      valid: valid,
      role: role,
      relatedStudent: relatedStudent?.toDomain(),
      relatedTeacher: relatedTeacher?.toDomain(),
    );
  }
}

class RegistrationPersonInfoDto {
  const RegistrationPersonInfoDto({
    required this.userId,
    required this.username,
    required this.fullName,
  });

  final int userId;
  final String username;
  final String fullName;

  factory RegistrationPersonInfoDto.fromJson(Map<String, dynamic> json) {
    return RegistrationPersonInfoDto(
      userId: _parseInt(json['user_id']) ?? 0,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
    );
  }

  RegistrationPersonInfo toDomain() {
    return RegistrationPersonInfo(
      userId: userId,
      username: username,
      fullName: fullName,
    );
  }
}

Map<String, dynamic>? _parseMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  return null;
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
