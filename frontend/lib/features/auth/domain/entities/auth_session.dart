class AuthSession {
  const AuthSession({
    required this.token,
    required this.username,
    required this.roles,
    this.userId,
  });

  final String token;
  final String username;
  final List<String> roles;
  final int? userId;

  bool get isAdmin => roles.contains('admin');

  AuthSession copyWith({
    String? token,
    String? username,
    List<String>? roles,
    int? userId,
  }) {
    return AuthSession(
      token: token ?? this.token,
      username: username ?? this.username,
      roles: roles ?? this.roles,
      userId: userId ?? this.userId,
    );
  }
}
