import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error surfaced by [ApiClient].
///
/// [statusCode] is 0 when the request never reached the server (offline,
/// DNS failure, timeout). [code] is the backend's machine-readable error
/// code (`ACCOUNT_EXISTS`, `NODE_REJECTED`, `AUTH_EXPIRED`, …) which the UI
/// branches on; [message] is safe to show to the user.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => message;
}

/// Thin JSON client for the election backend.
///
/// The bearer token is held in [token] (set by the session layer) and an
/// HTTP 401 clears it and fires [onUnauthorized] so the app can sign out.
class ApiClient {
  final String baseUrl;
  final http.Client _http;

  String? token;
  void Function()? onUnauthorized;

  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> getJson(String path) async =>
      _request('GET', path);

  Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> body) async =>
      _request('POST', path, body);

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) async =>
      _request('PATCH', path, body);

  Future<Map<String, dynamic>> _request(
      String method, String path, [Map<String, dynamic>? body]) async {
    http.Response res;
    try {
      final uri = _uri(path);
      final payload = body == null ? null : jsonEncode(body);
      res = switch (method) {
        'GET' => await _http.get(uri, headers: _headers),
        'POST' => await _http.post(uri, headers: _headers, body: payload),
        'PATCH' => await _http.patch(uri, headers: _headers, body: payload),
        _ => throw ApiException(0, 'NETWORK', 'Unsupported request method.'),
      };
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
          0, 'NETWORK', 'Network error. Check your connection and try again.');
    }

    if (res.statusCode == 401) {
      token = null;
      onUnauthorized?.call();
      throw const ApiException(401, 'UNAUTHORIZED', 'Your session has expired. Please sign in again.');
    }

    Map<String, dynamic> decoded = const <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        final value = jsonDecode(res.body);
        if (value is Map) decoded = value.cast<String, dynamic>();
      } catch (_) {
        // Non-JSON body — fall through to the generic error below.
      }
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        res.statusCode,
        decoded['code']?.toString() ?? 'HTTP_${res.statusCode}',
        decoded['message']?.toString() ??
            'Something went wrong (${res.statusCode}). Please try again.',
      );
    }
    return decoded;
  }
}
