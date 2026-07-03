class StudentProfileData {
  const StudentProfileData({
    required this.fullName,
    required this.birthday,
    required this.status,
  });

  final String fullName;
  final DateTime birthday;
  final String status;
}

class StudentChildInfo {
  const StudentChildInfo({
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
}

class ParentProfileData {
  const ParentProfileData({
    required this.fullName,
    required this.status,
    required this.children,
  });

  final String fullName;
  final String status;
  final List<StudentChildInfo> children;
}

class TeacherProfileData {
  const TeacherProfileData({
    required this.fullName,
    required this.status,
  });

  final String fullName;
  final String status;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.createdAt,
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
  final DateTime createdAt;
  final List<String> roles;
  final StudentProfileData? studentData;
  final ParentProfileData? parentData;
  final TeacherProfileData? teacherData;
}
