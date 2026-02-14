import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth.dart';
import '../models/hometask.dart';
import '../config/app_config.dart';
import 'app_data_cache_service.dart';

class HometaskService extends ChangeNotifier {
  final AuthService authService;
  final String baseUrl;
  final AppDataCacheService _cache = AppDataCacheService.instance;

  List<Hometask> _hometasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentUserId;
  String? _currentUsername;
  String? _currentFullName;
  String? _lastToken;

  HometaskService({
    required this.authService,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.instance.baseUrl {
    _lastToken = authService.token;
  }

  List<Hometask> get hometasks => _hometasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String _hometasksCacheKey(int studentId, String status) {
    return 'hometasks:$studentId:$status';
  }

  void syncAuth() {
    final token = authService.token;
    if (token != _lastToken) {
      _lastToken = token;
      _currentUserId = null;
      _currentUsername = null;
      _currentFullName = null;
      _hometasks = [];
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchActiveForCurrentStudent() async {
    if (!_hasRole('student')) {
      _hometasks = [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final userId = await _ensureCurrentUserId();
    if (userId == null) {
      _errorMessage ??= 'Failed to load student profile';
      notifyListeners();
      return;
    }

    await fetchHometasksForStudent(studentId: userId, status: 'active');
  }

  Future<void> fetchHometasksForStudent({
    required int studentId,
    String status = 'active',
  }) async {
    if (authService.token == null) return;

    final cacheKey = _hometasksCacheKey(studentId, status);

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (_hometasks.isEmpty) {
      final cached = await _cache.readJsonList(cacheKey, authService.userId);
      if (cached != null && cached.isNotEmpty) {
        _hometasks = cached
            .whereType<Map<String, dynamic>>()
            .map((item) => Hometask.fromJson(item))
            .toList();
        notifyListeners();
      }
    }

    try {
      final uri = Uri.parse('$baseUrl/api/students/$studentId/hometasks')
          .replace(queryParameters: {'status': status});

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _hometasks = data.map((item) => Hometask.fromJson(item)).toList();
        await _cache.writeJson(cacheKey, authService.userId, data);
      } else {
        _errorMessage = 'Failed to load hometasks: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error loading hometasks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearLocalCache() {
    _hometasks = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markCompleted(int hometaskId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/hometasks/$hometaskId/status'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'completed_by_student',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking hometask completed: $e');
      }
    }

    return false;
  }

  Future<bool> markAccomplished(int hometaskId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/hometasks/$hometaskId/status'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'accomplished_by_teacher',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking hometask accomplished: $e');
      }
    }

    return false;
  }

  Future<bool> markReopened(int hometaskId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/hometasks/$hometaskId/status'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'assigned',
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reopening hometask: $e');
      }
    }

    return false;
  }

  Future<bool> updateChecklistItems({
    required int hometaskId,
    required List<ChecklistItem> items,
  }) async {
    if (authService.token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/hometasks/$hometaskId/checklist'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'items': items
              .map((item) {
                final itemMap = <String, dynamic>{'text': item.text};
                if (item.progress != null) {
                  itemMap['progress'] = item.progress;
                } else {
                  itemMap['is_done'] = item.isDone;
                }
                return itemMap;
              })
              .toList(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating checklist items: $e');
      }
      return false;
    }
  }

  Future<bool> createHometask({
    required int studentId,
    required String title,
    String? description,
    DateTime? dueDate,
    required HometaskType hometaskType,
    List<String>? items,
    int? repeatEveryDays,
  }) async {
    if (authService.token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/hometasks'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'student_id': studentId,
          'title': title,
          'description': description,
          if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
          'hometask_type': _serializeType(hometaskType),
          if (items != null)
            'items': items.map((text) => {'text': text}).toList(),
          if (repeatEveryDays != null && repeatEveryDays > 0)
            'repeat_every_days': repeatEveryDays,
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating hometask: $e');
      }
      return false;
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
      case HometaskType.dailyRoutine:
        return 'daily_routine';
      case HometaskType.photoSubmission:
        return 'photo_submission';
      case HometaskType.textSubmission:
        return 'text_submission';
    }
  }

  Future<bool> updateHometaskOrder({
    required int studentId,
    required List<int> orderedIds,
  }) async {
    if (authService.token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/students/$studentId/hometasks/order'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'hometask_ids': orderedIds,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating hometask order: $e');
      }
      return false;
    }
  }

  Future<List<StudentSummary>> fetchStudentsForParent() async {
    if (authService.token == null) return [];

    final parentId = await _ensureCurrentUserId();
    if (parentId == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parents/$parentId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final children = data['children'] as List<dynamic>? ?? [];
      return children
          .whereType<Map<String, dynamic>>()
          .map(StudentSummary.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching parent students: $e');
      }
      return [];
    }
  }

  Future<List<StudentSummary>> fetchStudentsForTeacher() async {
    if (authService.token == null) return [];

    final teacherId = await _ensureCurrentUserId();
    if (teacherId == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/teachers/$teacherId/students'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(StudentSummary.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching teacher students: $e');
      }
      return [];
    }
  }

  Future<int?> getCurrentUserId() async {
    return _ensureCurrentUserId();
  }

  Future<StudentSummary?> getCurrentStudentSummary() async {
    if (!_hasRole('student')) return null;

    final userId = await _ensureCurrentUserId();
    if (userId == null) return null;

    final username = _currentUsername ?? '';
    final fullName = (_currentFullName ?? '').isNotEmpty
        ? _currentFullName!
        : username;

    return StudentSummary(
      userId: userId,
      username: username,
      fullName: fullName.isNotEmpty ? fullName : 'Student',
    );
  }

  Future<int?> _ensureCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId;
    if (authService.token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUserId = data['id'];
        _currentUsername = data['username'];
        final studentData = data['student_data'];
        if (studentData is Map<String, dynamic>) {
          _currentFullName = studentData['full_name'];
        } else {
          _currentFullName = null;
        }
        return _currentUserId;
      }
    } catch (_) {}

    _errorMessage = 'Failed to load profile data';
    return null;
  }

  bool _hasRole(String role) {
    return authService.roles.contains(role);
  }
}
