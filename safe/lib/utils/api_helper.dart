import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../first.dart';

///
/// 🌐 API HELPER (Dynamic Backend URL + Token Handling)
///
class ApiHelper {
  // 🔐 Secure Storage
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // ⏱ Request timeout
  static const Duration _timeout = Duration(seconds: 20);

  // 🔑 STORAGE KEYS
  static const String _baseUrlKey = 'backend_base_url';
  static const String _tokenKey = 'auth_token';

  // ============================================================
  // 🌍 BASE URL HANDLING (NGROK / LOCAL / PROD)
  // ============================================================

  /// Get stored backend URL
  static Future<String?> getBaseUrl() async {
    return await _storage.read(key: _baseUrlKey);
  }

  /// Save backend URL (ngrok)
  static Future<void> saveBaseUrl(String url) async {
    // Normalize (remove trailing slash)
    final cleaned = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _storage.write(key: _baseUrlKey, value: cleaned);
  }

  /// Clear backend URL
  static Future<void> clearBaseUrl() async {
    await _storage.delete(key: _baseUrlKey);
  }

  /// Build full API URL
  static Future<Uri> _buildUri(String endpoint) async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception("Backend URL not configured");
    }
    return Uri.parse("$baseUrl/api$endpoint");
  }

  // ============================================================
  // ❤️ HEALTH CHECK (USED AT APP START)
  // ============================================================

  static Future<bool> checkBackendHealth() async {
    try {
      final baseUrl = await getBaseUrl();
      if (baseUrl == null) return false;

      final uri = Uri.parse("$baseUrl/api/health");
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // 🔑 TOKEN HANDLING
  // ============================================================

  static Future<String?> _getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<Map<String, String>> _headers({
    bool authRequired = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authRequired) {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ============================================================
  // 📥 GET
  // ============================================================

  static Future<http.Response> get(
    String endpoint, {
    bool authRequired = true,
  }) async {
    final uri = await _buildUri(endpoint);
    final headers = await _headers(authRequired: authRequired);

    return await http.get(uri, headers: headers).timeout(_timeout);
  }

  // ============================================================
  // 📤 POST
  // ============================================================

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    final uri = await _buildUri(endpoint);
    final headers = await _headers(authRequired: authRequired);

    return await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
  }

  // ============================================================
  // ✏️ PUT
  // ============================================================

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    final uri = await _buildUri(endpoint);
    final headers = await _headers(authRequired: authRequired);

    return await http
        .put(uri, headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
  }

  // ============================================================
  // ❌ DELETE
  // ============================================================

  static Future<http.Response> delete(
    String endpoint, {
    bool authRequired = true,
  }) async {
    final uri = await _buildUri(endpoint);
    final headers = await _headers(authRequired: authRequired);

    return await http.delete(uri, headers: headers).timeout(_timeout);
  }

  // ============================================================
  // 📎 FILE UPLOAD
  // ============================================================

  static Future<http.StreamedResponse> uploadFile({
    required String endpoint,
    required File file,
    required Map<String, String> fields,
    String fileField = "file",
  }) async {
    final uri = await _buildUri(endpoint);
    final token = await _getToken();

    final request = http.MultipartRequest("POST", uri);

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileField, file.path));

    return await request.send();
  }

  // ============================================================
  // 🚪 LOGOUT
  // ============================================================

  static Future<void> logout(BuildContext context) async {
    await _storage.deleteAll();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const FirstScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // ⚠️ RESPONSE HANDLER
  // ============================================================

  static dynamic handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      throw Exception("Session expired. Please login again.");
    }

    throw Exception("API Error (${response.statusCode}): ${response.body}");
  }
}
