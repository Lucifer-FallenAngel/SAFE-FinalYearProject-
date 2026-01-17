import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'secure_storage.dart';

///
/// 🌍 BACKEND CONFIG (Ngrok / Dynamic Server)
///
class BackendConfig {
  static const Duration _timeout = Duration(seconds: 5);

  /// Get stored backend base URL
  static Future<String?> getBaseUrl() async {
    return await SecureStorage.getBackendUrl();
  }

  /// Save backend URL
  static Future<void> setBaseUrl(String url) async {
    final cleaned = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await SecureStorage.saveBackendUrl(cleaned);
  }

  /// Check if backend is reachable
  static Future<bool> isBackendAlive(String baseUrl) async {
    try {
      final uri = Uri.parse("$baseUrl/api/auth/ping");

      final response = await http.get(uri).timeout(_timeout);

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
