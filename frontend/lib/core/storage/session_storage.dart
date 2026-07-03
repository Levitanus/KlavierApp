import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'jwt_token';

  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_tokenKey);
  }

  Future<void> writeToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}
