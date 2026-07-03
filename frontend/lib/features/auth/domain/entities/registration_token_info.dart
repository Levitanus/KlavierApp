class RegistrationPersonInfo {
  const RegistrationPersonInfo({
    required this.userId,
    required this.username,
    required this.fullName,
  });

  final int userId;
  final String username;
  final String fullName;
}

class RegistrationTokenInfo {
  const RegistrationTokenInfo({
    required this.valid,
    this.role,
    this.relatedStudent,
    this.relatedTeacher,
  });

  final bool valid;
  final String? role;
  final RegistrationPersonInfo? relatedStudent;
  final RegistrationPersonInfo? relatedTeacher;

  bool get isStudent => role == 'student';
  bool get isParent => role == 'parent';
  bool get isTeacher => role == 'teacher';
}
