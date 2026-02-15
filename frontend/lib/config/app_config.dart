import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._(this.baseUrl);

  final String baseUrl;

  static AppConfig? _instance;

  static AppConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError('AppConfig not loaded');
    }
    return config;
  }

  static Future<void> load() async {
    const envBaseUrl = String.fromEnvironment('API_BASE_URL');
    final baseUrl = envBaseUrl.trim().isNotEmpty
        ? envBaseUrl.trim()
        : await _loadBaseUrlFromConfig();
    _instance = AppConfig._(baseUrl);
  }

  static Future<String> _loadBaseUrlFromConfig() async {
    final raw = await rootBundle.loadString('assets/config.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final baseUrl = (data['baseUrl'] as String?)?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('config.json missing baseUrl');
    }
    return baseUrl;
  }
}
