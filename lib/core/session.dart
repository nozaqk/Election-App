import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Persists the bearer token (with its expiry) across app restarts.
class SessionStore {
  static const String _key = 'session';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final exp = DateTime.now()
        .add(AppConfig.sessionLifetime)
        .millisecondsSinceEpoch;
    await prefs.setString(_key, jsonEncode({'token': token, 'exp': exp}));
  }

  /// Returns the stored token, or null if absent / expired / corrupt.
  Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final exp = (data['exp'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > exp) {
        await prefs.remove(_key);
        return null;
      }
      final token = data['token']?.toString();
      return (token == null || token.isEmpty) ? null : token;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
