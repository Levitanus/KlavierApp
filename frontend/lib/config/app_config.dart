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
    final raw = await rootBundle.loadString('assets/config.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final baseUrl = (data['baseUrl'] as String?)?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('config.json missing baseUrl');
    }
    _instance = AppConfig._(baseUrl);
  }
}
