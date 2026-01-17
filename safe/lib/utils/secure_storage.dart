import 'package:flutter_secure_storage/flutter_secure_storage.dart';

///
/// 🔐 SECURE STORAGE (Single Source of Truth)
///
class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // -------------------------------
  // 🔑 KEYS
  // -------------------------------
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _profilePicKey = 'profile_pic';
  static const _backendUrlKey = 'backend_base_url';

  // ============================================================
  // 🔐 LOGIN SESSION
  // ============================================================

  static Future<void> saveLogin({
    required String token,
    required String userId,
    required String userName,
    String? profilePic,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userNameKey, value: userName);

    if (profilePic != null && profilePic.isNotEmpty) {
      await _storage.write(key: _profilePicKey, value: profilePic);
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<Map<String, String?>> getUser() async {
    return {
      'id': await _storage.read(key: _userIdKey),
      'name': await _storage.read(key: _userNameKey),
      'profile_pic': await _storage.read(key: _profilePicKey),
    };
  }

  // ============================================================
  // 🌍 BACKEND / NGROK URL
  // ============================================================

  static Future<void> saveBackendUrl(String url) async {
    final cleaned = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    await _storage.write(key: _backendUrlKey, value: cleaned);
  }

  static Future<String?> getBackendUrl() async {
    return await _storage.read(key: _backendUrlKey);
  }

  static Future<void> clearBackendUrl() async {
    await _storage.delete(key: _backendUrlKey);
  }

  // ============================================================
  // 🚪 LOGOUT / CLEAR
  // ============================================================

  /// Clears login but keeps backend URL (recommended)
  static Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _profilePicKey);
  }

  /// Clears EVERYTHING (including backend URL)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
