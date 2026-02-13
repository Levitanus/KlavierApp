import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decode/jwt_decode.dart';
import 'config/app_config.dart';

class AuthService extends ChangeNotifier {
  static const String _tokenKey = 'jwt_token';
  static String get _baseUrl => AppConfig.instance.baseUrl;
  
  String? _token;
  bool _isAuthenticated = false;
  List<String> _roles = [];
  int? _userId;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  List<String> get roles => _roles;
  bool get isAdmin => _roles.contains('admin');
  int? get userId => _userId;

  LoginResult _loginFailure(String message) {
    return LoginResult.failure(message);
  }

  AuthService() {
    _loadToken();
  }

  /// Decode JWT and extract roles and user ID
  void _decodeToken(String token) {
    try {
      final payload = Jwt.parseJwt(token);
      if (payload['roles'] != null) {
        _roles = List<String>.from(payload['roles']);
      } else {
        _roles = [];
      }
      if (payload['user_id'] != null) {
        final rawUserId = payload['user_id'];
        if (rawUserId is int) {
          _userId = rawUserId;
        } else if (rawUserId is String) {
          _userId = int.tryParse(rawUserId);
        } else if (rawUserId is num) {
          _userId = rawUserId.toInt();
        } else {
          _userId = null;
        }
      } else {
        _userId = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error decoding token: $e');
      }
      _roles = [];
      _userId = null;
    }
  }

  /// Load JWT token from SharedPreferences
  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _isAuthenticated = _token != null && _token!.isNotEmpty;
      if (_isAuthenticated && _token != null) {
        _decodeToken(_token!);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading token: $e');
      }
      _isAuthenticated = false;
    }
  }

  /// Save JWT token to SharedPreferences
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _token = token;
      _isAuthenticated = true;
      _decodeToken(token);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving token: $e');
      }
      throw Exception('Failed to save authentication token');
    }
  }

  /// Remove JWT token from SharedPreferences
  Future<void> _removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      _token = null;
      _isAuthenticated = false;
      _roles = [];
      _userId = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing token: $e');
      }
    }
  }

  /// Login with username and password
  Future<LoginResult> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        
        if (token != null && token.isNotEmpty) {
          await _saveToken(token);
          return const LoginResult.success();
        }
      }
      
      return _loginFailure('Invalid username or password');
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return _loginFailure('Network error. Check your connection and try again.');
    }
  }

  /// Logout and remove token
  Future<void> logout() async {
    await _removeToken();
  }

  /// Check if the stored token is still valid (optional: you can implement token validation)
  Future<bool> validateToken() async {
    if (_token == null || _token!.isEmpty) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/validate'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        await _removeToken();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Token validation error: $e');
      }
      return false;
    }
  }
}

class LoginResult {
  final bool success;
  final String? errorMessage;

  const LoginResult.success()
      : success = true,
        errorMessage = null;

  const LoginResult.failure(this.errorMessage) : success = false;
}
