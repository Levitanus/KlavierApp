import 'dart:convert';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_data_cache_service.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../domain/entities/hometask.dart';

class HometaskRepository {
  HometaskRepository({
    required ApiClient apiClient,
    required AuthSession session,
    AppDataCacheService? cache,
  })  : _apiClient = apiClient,
        _session = session,
        _cache = cache ?? AppDataCacheService.instance;

  final ApiClient _apiClient;
  final AuthSession _session;
  final AppDataCacheService _cache;

  int? _currentUserId;
  String? _currentUsername;
  String? _currentFullName;

  int? get _cacheScopeUserId => _session.userId ?? _currentUserId;

  bool get _hasStudentRole => _session.roles.contains('student');

  String _hometasksCacheKey(int studentId, String status) {
    return 'hometasks:$studentId:$status';
  }

  Future<List<Hometask>> fetchActiveForCurrentStudent() async {
    if (!_hasStudentRole) {
      return const <Hometask>[];
    }

    final userId = await getCurrentUserId();
    if (userId == null) {
      throw const AppException('Failed to load student profile');
    }

    return fetchHometasksForStudent(studentId: userId, status: 'active');
  }

  Future<List<Hometask>> fetchHometasksForStudent({
    required int studentId,
    String status = 'active',
  }) async {
    final cacheKey = _hometasksCacheKey(studentId, status);
    final cached = await _cache.readJsonList(cacheKey, _cacheScopeUserId);

    if (cached != null && cached.isNotEmpty) {
      final cachedTasks = cached
          .whereType<Map<String, dynamic>>()
          .map(Hometask.fromJson)
          .toList(growable: false);
      if (cachedTasks.isNotEmpty) {
        return cachedTasks;
      }
    }

    final response = await _apiClient.get(
      '/api/students/$studentId/hometasks',
      token: _session.token,
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to load hometasks.',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    await _cache.writeJson(cacheKey, _cacheScopeUserId, data);
    return data
        .whereType<Map<String, dynamic>>()
        .map(Hometask.fromJson)
        .toList(growable: false);
  }

  Future<void> markCompleted(int hometaskId) async {
    final response = await _apiClient.putJson(
      '/api/hometasks/$hometaskId/status',
      token: _session.token,
      body: <String, dynamic>{'status': 'completed_by_student'},
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to update hometask.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> markAccomplished(
    int hometaskId, {
    bool applyToGroup = false,
  }) async {
    final response = await _apiClient.putJson(
      '/api/hometasks/$hometaskId/status',
      token: _session.token,
      body: <String, dynamic>{
        'status': 'accomplished_by_teacher',
        if (applyToGroup) 'apply_to_group': true,
      },
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to update hometask.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> markReopened(
    int hometaskId, {
    bool applyToGroup = false,
  }) async {
    final response = await _apiClient.putJson(
      '/api/hometasks/$hometaskId/status',
      token: _session.token,
      body: <String, dynamic>{
        'status': 'assigned',
        if (applyToGroup) 'apply_to_group': true,
      },
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to update hometask.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> updateChecklistItems({
    required int hometaskId,
    required List<ChecklistItem> items,
  }) async {
    final response = await _apiClient.putJson(
      '/api/hometasks/$hometaskId/checklist',
      token: _session.token,
      body: <String, dynamic>{
        'items': items
            .map(
              (item) => item.toJson(
                includeProgress: item.progress != null,
              ),
            )
            .toList(growable: false),
      },
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to save items.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> createHometask({
    int? studentId,
    int? groupId,
    required String title,
    String? description,
    DateTime? dueDate,
    required HometaskType hometaskType,
    List<String>? items,
    int? repeatEveryDays,
  }) async {
    if ((studentId == null && groupId == null) ||
        (studentId != null && groupId != null)) {
      throw const AppException('Provide either student_id or group_id.');
    }

    final itemPayload = items?.map((text) => <String, dynamic>{'text': text}).toList(growable: false);

    final payload = <String, dynamic>{
      'title': title,
      'hometask_type': _serializeType(hometaskType),
    };
    if (studentId != null) {
      payload['student_id'] = studentId;
    }
    if (groupId != null) {
      payload['group_id'] = groupId;
    }
    if (description != null) {
      payload['description'] = description;
    }
    if (dueDate != null) {
      payload['due_date'] = dueDate.toUtc().toIso8601String();
    }
    if (itemPayload != null) {
      payload['items'] = itemPayload;
    }
    if (repeatEveryDays != null && repeatEveryDays > 0) {
      payload['repeat_every_days'] = repeatEveryDays;
    }

    final response = await _apiClient.postJson(
      '/api/hometasks',
      token: _session.token,
      body: payload,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to create hometask.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> updateHometask({
    required int hometaskId,
    String? title,
    String? description,
    List<ChecklistItem>? items,
    bool applyToGroup = false,
  }) async {
    final itemsPayload = items
        ?.map(
          (item) => item.toJson(
            includeProgress: item.progress != null,
          ),
        )
        .toList(growable: false);

    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title;
    }
    if (description != null) {
      payload['description'] = description;
    }
    if (itemsPayload != null) {
      payload['items'] = itemsPayload;
    }
    if (applyToGroup) {
      payload['apply_to_group'] = true;
    }

    final response = await _apiClient.putJson(
      '/api/hometasks/$hometaskId',
      token: _session.token,
      body: payload,
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to update hometask.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> updateHometaskOrder({
    required int studentId,
    required List<int> orderedIds,
  }) async {
    final response = await _apiClient.putJson(
      '/api/students/$studentId/hometasks/order',
      token: _session.token,
      body: <String, dynamic>{'hometask_ids': orderedIds},
    );

    if (response.statusCode != 200) {
      throw AppException(
        _extractErrorMessage(response.body) ?? 'Failed to update order.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<StudentSummary>> fetchStudentsForParent() async {
    final parentId = await getCurrentUserId();
    if (parentId == null) {
      return const <StudentSummary>[];
    }

    final response = await _apiClient.get(
      '/api/parents/$parentId',
      token: _session.token,
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      return const <StudentSummary>[];
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final children = payload['children'] as List<dynamic>? ?? const [];
    return children
        .whereType<Map<String, dynamic>>()
        .map(StudentSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<StudentSummary>> fetchStudentsForTeacher() async {
    final teacherId = await getCurrentUserId();
    if (teacherId == null) {
      return const <StudentSummary>[];
    }

    final response = await _apiClient.get(
      '/api/teachers/$teacherId/students',
      token: _session.token,
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      return const <StudentSummary>[];
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(StudentSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<StudentGroupSummary>> fetchGroupsForTeacher() async {
    final teacherId = await getCurrentUserId();
    if (teacherId == null) {
      return const <StudentGroupSummary>[];
    }

    final response = await _apiClient.get(
      '/api/teachers/$teacherId/groups',
      token: _session.token,
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      return const <StudentGroupSummary>[];
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(StudentGroupSummary.fromJson)
        .toList(growable: false);
  }

  Future<int?> getCurrentUserId() async {
    if (_session.userId != null) {
      _currentUserId = _session.userId;
      return _currentUserId;
    }

    if (_currentUserId != null) {
      return _currentUserId;
    }

    await _ensureCurrentProfile();
    return _currentUserId;
  }

  Future<StudentSummary?> getCurrentStudentSummary() async {
    if (!_hasStudentRole) {
      return null;
    }

    final userId = await getCurrentUserId();
    if (userId == null) {
      return null;
    }

    final username = _currentUsername ?? _session.username;
    final fullName = (_currentFullName ?? '').trim().isNotEmpty
        ? _currentFullName!.trim()
        : username;

    return StudentSummary(
      userId: userId,
      username: username,
      fullName: fullName.isNotEmpty ? fullName : 'Student',
    );
  }

  Future<void> clearLocalCache() async {
    await _cache.clearUserData(_cacheScopeUserId);
  }

  Future<void> _ensureCurrentProfile() async {
    final response = await _apiClient.get(
      '/api/profile',
      token: _session.token,
      headers: const {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw const AppException('Failed to load profile data');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _currentUserId = (data['id'] as num?)?.toInt();
    _currentUsername = data['username'] as String?;

    final studentData = data['student_data'];
    if (studentData is Map<String, dynamic>) {
      _currentFullName = studentData['full_name'] as String?;
    } else {
      _currentFullName = null;
    }
  }

  String _serializeType(HometaskType type) {
    switch (type) {
      case HometaskType.simple:
        return 'simple';
      case HometaskType.checklist:
        return 'checklist';
      case HometaskType.progress:
        return 'progress';
      case HometaskType.freeAnswer:
        return 'free_answer';
      case HometaskType.dailyRoutine:
        return 'daily_routine';
      case HometaskType.photoSubmission:
        return 'photo_submission';
      case HometaskType.textSubmission:
        return 'text_submission';
    }
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
}