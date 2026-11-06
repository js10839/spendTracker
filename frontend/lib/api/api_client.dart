import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Supplies an existing token. Login, storage, expiry, and refresh are the
/// caller's responsibility; the client asks for a token on every request.
typedef AccessTokenProvider = FutureOr<String?> Function();

class MissingAccessTokenException implements Exception {
  const MissingAccessTokenException();

  @override
  String toString() => 'An access token is required to call the API.';
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, this.detail});

  final int statusCode;

  /// FastAPI detail may be a string or a list of validation errors.
  final Object? detail;

  // Avoid logging response bodies or request credentials implicitly.
  @override
  String toString() => 'API request failed (HTTP $statusCode).';
}

/// Shared JSON transport for FastAPI. Works on web and native via package:http.
///
/// Supply the backend base URL explicitly (an optional path prefix is allowed).
/// An injected http.Client is owned by the caller; otherwise close() releases
/// the transport created here. Requests are not automatically retried, including
/// on 401: session handling is intentionally outside this class.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl,
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (!['http', 'https'].contains(baseUrl.scheme) ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Use an HTTP(S) backend URL without credentials, query, or fragment',
      );
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive');
    }
  }

  final Uri _baseUrl;
  final AccessTokenProvider accessToken;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  bool _closed = false;

  Future<Object?> getJson(
    List<String> pathSegments, {
    Map<String, String> queryParameters = const {},
  }) => _request('GET', pathSegments, queryParameters: queryParameters);

  Future<Object?> putJson(
    List<String> pathSegments, {
    required Map<String, Object?> body,
  }) => _request('PUT', pathSegments, body: body);

  Future<Object?> _request(
    String method,
    List<String> pathSegments, {
    Map<String, String> queryParameters = const {},
    Map<String, Object?>? body,
  }) async {
    if (_closed) throw StateError('ApiClient has been closed');
    if (pathSegments.any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw ArgumentError('Request path segments cannot be empty, . or ..');
    }
    final token = (await accessToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const MissingAccessTokenException();
    }
    if (_closed) throw StateError('ApiClient has been closed');
    final uri = _baseUrl.replace(
      pathSegments: [
        ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...pathSegments,
      ],
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    // Covers both receipt of headers and consumption of the response body.
    final response = await (() async => http.Response.fromStream(
      await _client.send(request),
    ))().timeout(timeout);
    final success = response.statusCode >= 200 && response.statusCode < 300;
    Object? json;
    try {
      json = response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (success) throw const FormatException('API returned invalid JSON');
    }
    if (!success) {
      throw ApiException(
        statusCode: response.statusCode,
        detail: json is Map<String, dynamic> ? json['detail'] : null,
      );
    }
    return json;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }
}
