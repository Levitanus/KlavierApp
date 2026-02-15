import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../auth.dart';
import '../config/app_config.dart';

class PushNotificationService extends ChangeNotifier {
  PushNotificationService({
    required this.authService,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.instance.baseUrl;

  final AuthService authService;
  final String baseUrl;

  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _lastToken;

  static const String _webVapidKey =
      'BBfVex9gB0NAnQKNly8kbOvBZ4mnAhPyO78kYgf375WKXoiclmB54RNiXpntHGCgJaNQEmLaXl5sQ5LbRIo56GU';

  Future<void> syncAuth() async {
    if (kDebugMode) {
      print('[PUSH] syncAuth called, authenticated: ${authService.isAuthenticated}');
    }
    if (!authService.isAuthenticated || authService.token == null) {
      if (kDebugMode) {
        print('[PUSH] Not authenticated, revoking tokens');
      }
      await _revokeTokenIfNeeded();
      return;
    }

    if (_initialized) {
      if (kDebugMode) {
        print('[PUSH] Already initialized, returning');
      }
      return;
    }

    if (!_isSupportedPlatform()) {
      if (kDebugMode) {
        print('[PUSH] Platform not supported');
      }
      return;
    }

    if (kDebugMode) {
      print('[PUSH] Starting initialization...');
    }
    _initialized = true;
    await _requestPermissionAndRegister();

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        if (kDebugMode) {
          print('[PUSH] Token refreshed: $token');
        }
        return _registerToken(token);
      },
    );
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  bool _isSupportedPlatform() {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<bool> requestPermissionAndRegister() async {
    if (!_isSupportedPlatform()) {
      return false;
    }
    return _requestPermissionAndRegister();
  }

  Future<bool> _requestPermissionAndRegister() async {
    try {
      if (kDebugMode) {
        print('[PUSH] Requesting permission...');
      }
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (kDebugMode) {
        print('[PUSH] Permission status: ${settings.authorizationStatus}');
      }
      final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorized) {
        if (kDebugMode) {
          print('[PUSH] Permission not authorized');
        }
        return false;
      }

      final token = await _fetchToken();
      if (kDebugMode) {
        print('[PUSH] Token fetched: ${token?.substring(0, token.length.clamp(0, 30)) ?? "<null>"}...');
      }
      if (token == null) {
        if (kDebugMode) {
          print('[PUSH] Token is null');
        }
        return false;
      }

      if (kDebugMode) {
        print('[PUSH] Registering token with backend...');
      }
      await _registerToken(token);
      if (kDebugMode) {
        print('[PUSH] Token registration completed');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[PUSH] Init error: $e');
      }
      return false;
    }
  }

  Future<String?> _fetchToken() async {
    if (kIsWeb) {
      return FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey);
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _registerToken(String token) async {
    if (authService.token == null) {
      if (kDebugMode) {
        print('[PUSH] Cannot register: no auth token');
      }
      return;
    }

    _lastToken = token;

    if (kDebugMode) {
      print('[PUSH] Posting to: $baseUrl/api/push/tokens');
      print('[PUSH] Auth token: ${authService.token?.substring(0, 20)}...');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/push/tokens'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'platform': kIsWeb ? 'web' : 'android',
        }),
      );

      if (kDebugMode) {
        print('[PUSH] Register response status: ${response.statusCode}');
        if (response.statusCode >= 400) {
          print('[PUSH] Register failed: ${response.body}');
        } else {
          print('[PUSH] Register success');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PUSH] Register request error: $e');
      }
    }
  }

  Future<void> _revokeTokenIfNeeded() async {
    if (_lastToken == null || authService.token == null) {
      _lastToken = null;
      return;
    }

    final token = _lastToken;
    _lastToken = null;

    try {
      await http.post(
        Uri.parse('$baseUrl/api/push/tokens/revoke'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to revoke push token: $e');
      }
    }
  }
}
