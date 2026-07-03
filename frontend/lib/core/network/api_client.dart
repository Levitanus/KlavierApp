import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  Uri _uri(String path) => Uri.parse('${AppConfig.instance.baseUrl}$path');

  Future<http.Response> get(
    String path, {
    String? token,
    Map<String, String>? headers,
  }) {
    return http.get(_uri(path), headers: _headers(token: token, headers: headers));
  }

  Future<http.Response> postJson(
    String path, {
    required Map<String, dynamic> body,
    String? token,
    Map<String, String>? headers,
  }) {
    return http.post(
      _uri(path),
      headers: _headers(token: token, headers: headers),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> putJson(
    String path, {
    required Map<String, dynamic> body,
    String? token,
    Map<String, String>? headers,
  }) {
    return http.put(
      _uri(path),
      headers: _headers(token: token, headers: headers),
      body: jsonEncode(body),
    );
  }

  Map<String, String> _headers({
    String? token,
    Map<String, String>? headers,
  }) {
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };
  }
}
