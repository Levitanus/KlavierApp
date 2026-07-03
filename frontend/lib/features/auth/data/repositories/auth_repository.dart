import 'dart:convert';

import 'package:jwt_decode/jwt_decode.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/registration_token_info.dart';
import '../dto/login_response_dto.dart';
import '../dto/registration_token_info_dto.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SessionStorage sessionStorage,
    required LocalPreferences localPreferences,
  })
      : _apiClient = apiClient,
        _sessionStorage = sessionStorage,
        _localPreferences = localPreferences;

  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;
  final LocalPreferences _localPreferences;

  Future<AuthSession?> restoreSession() async {
    final token = await _sessionStorage.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final isValid = await _validateToken(token);
    if (!isValid) {
      await _sessionStorage.clearToken();
      return null;
    }

    return _resolveSession(token);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/api/auth/login',
      body: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Invalid username or password',
        statusCode: response.statusCode,
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final dto = LoginResponseDto.fromJson(payload);
    if (dto.token.isEmpty) {
      throw const AppException('Login response did not contain a token.');
    }

    await _sessionStorage.writeToken(dto.token);
    return _resolveSession(dto.token);
  }

  Future<void> logout() {
    return _sessionStorage.clearToken();
  }

  Future<String> requestPasswordReset({required String username}) async {
    final response = await _apiClient.postJson(
      '/api/auth/forgot-password',
      body: <String, dynamic>{'username': username},
    );

    if (response.statusCode != 200) {
      throw AppException(
        'Failed to request password reset.',
        statusCode: response.statusCode,
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['message'] as String? ??
        'If your username exists and has an email, you will receive a password reset link.';
  }

  Future<({bool valid, String? username})> validateResetToken(String token) async {
    final response = await _apiClient.get('/api/auth/reset-password/$token');
    if (response.statusCode != 200) {
      return (valid: false, username: null);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      valid: payload['valid'] == true,
      username: payload['username'] as String?,
    );
  }

  Future<String> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/api/auth/reset-password/$token',
      body: <String, dynamic>{'password': password},
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to reset password.',
        statusCode: response.statusCode,
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['message'] as String? ?? 'Password reset successfully';
  }

  Future<RegistrationTokenInfo> fetchRegistrationTokenInfo(String token) async {
    final response = await _apiClient.get('/api/registration-token-info/$token');
    if (response.statusCode != 200) {
      throw AppException(
        'Failed to validate registration token.',
        statusCode: response.statusCode,
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return RegistrationTokenInfoDto.fromJson(payload).toDomain();
  }

  Future<void> registerWithToken({
    required String token,
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phone,
    String? birthday,
    required bool consentAccepted,
  }) async {
    final response = await _apiClient.postJson(
      '/api/register-with-token',
      body: <String, dynamic>{
        'token': token,
        'username': username,
        'password': password,
        'email': _nullIfEmpty(email),
        'phone': _nullIfEmpty(phone),
        'full_name': fullName,
        if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
      },
    );

    if (response.statusCode != 201) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Registration failed.',
        statusCode: response.statusCode,
      );
    }

    await _localPreferences.setConsentAccepted(consentAccepted);
  }

  Future<AuthSession> _resolveSession(String token) async {
    final decoded = _decodeToken(token);
    return _enrichFromProfile(decoded);
  }

  Future<bool> _validateToken(String token) async {
    final response = await _apiClient.get('/api/auth/validate', token: token);
    return response.statusCode == 200;
  }

  Future<AuthSession> _enrichFromProfile(AuthSession session) async {
    final response = await _apiClient.get('/api/profile', token: session.token);
    if (response.statusCode != 200) {
      return session;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final roles = _parseRoles(payload['roles']) ?? session.roles;
    final userId = _parseInt(payload['id']) ?? session.userId;

    return session.copyWith(roles: roles, userId: userId);
  }

  AuthSession _decodeToken(String token) {
    final payload = Jwt.parseJwt(token);
    return AuthSession(
      token: token,
      username: payload['sub'] as String? ?? 'unknown',
      roles: _parseRoles(payload['roles']) ?? const <String>[],
      userId: _parseInt(payload['user_id']) ??
          _parseInt(payload['userId']) ??
          _parseInt(payload['uid']) ??
          _parseInt(payload['id']),
    );
  }

  List<String>? _parseRoles(dynamic raw) {
    if (raw is! List) {
      return null;
    }
    return raw.whereType<String>().toList(growable: false);
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

  String? _extractErrorMessage(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        return payload['error'] as String?;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
