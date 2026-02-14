import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppDataCacheService {
  AppDataCacheService._();

  static final AppDataCacheService instance = AppDataCacheService._();

  static const String _prefix = 'app_data_cache:';

  String _scopedKey(String key, int? userId) {
    final scope = userId?.toString() ?? 'anon';
    return '$_prefix$scope:$key';
  }

  Future<void> writeJson(String key, int? userId, Object? data) async {
    try {
      final payload = jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'data': data,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scopedKey(key, userId), payload);
    } catch (_) {
      // Cache errors should not break the app.
    }
  }

  Future<dynamic> readJson(String key, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopedKey(key, userId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readJsonMap(String key, int? userId) async {
    final data = await readJson(key, userId);
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<List<dynamic>?> readJsonList(String key, int? userId) async {
    final data = await readJson(key, userId);
    if (data is List) return data;
    return null;
  }

  Future<void> remove(String key, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scopedKey(key, userId));
    } catch (_) {
      // Ignore remove failures.
    }
  }

  Future<void> clearUserData(int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = userId?.toString() ?? 'anon';
      final prefix = '$_prefix$scope:';
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(prefix)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {
      // Ignore clear failures.
    }
  }
}
