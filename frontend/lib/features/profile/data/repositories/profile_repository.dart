import 'dart:convert';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../domain/entities/user_profile.dart';
import '../dto/user_profile_dto.dart';

class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<UserProfile> fetchCurrentProfile(AuthSession session) async {
    final response = await _apiClient.get('/api/profile', token: session.token);
    if (response.statusCode != 200) {
      throw AppException(
        'Failed to load profile',
        statusCode: response.statusCode,
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfileDto.fromJson(payload).toDomain();
  }

  Future<void> updateCurrentProfile({
    required AuthSession session,
    String? email,
    String? phone,
    String? fullName,
    String? birthday,
  }) async {
    final response = await _apiClient.putJson(
      '/api/profile',
      token: session.token,
      body: <String, dynamic>{
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'birthday': birthday,
      },
    );

    if (response.statusCode != 200) {
      throw AppException(
        'Failed to update profile',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> changePassword({
    required AuthSession session,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.postJson(
      '/api/profile/change-password',
      token: session.token,
      body: <String, dynamic>{
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );

    if (response.statusCode != 200) {
      throw AppException(
        'Failed to change password',
        statusCode: response.statusCode,
      );
    }
  }
}
