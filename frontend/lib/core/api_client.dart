import 'dart:convert';

import 'package:http/http.dart' as http;

/// 인증된 FastAPI 요청과 공통 오류 처리를 담당한다.
class ApiClient {
  ApiClient({required this.baseUri, required this.accessToken, http.Client? client}) : _client = client ?? http.Client();

  final Uri baseUri;
  final String? Function() accessToken;
  final http.Client _client;

  /// 요청 시점의 세션 토큰으로 JSON POST 요청을 보낸다.
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) => _request(path, isGet: false, body: body);

  /// 요청 시점의 세션 토큰으로 JSON GET 요청을 보낸다.
  Future<Map<String, dynamic>> get(String path) => _request(path, isGet: true);

  /// 인증과 응답 검증을 모든 요청에 동일하게 적용한다.
  Future<Map<String, dynamic>> _request(String path, {required bool isGet, Map<String, dynamic>? body}) async {
    final token = accessToken();
    if (token == null || token.isEmpty) throw StateError('Authentication required');
    final headers = {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final response = isGet ? await _client.get(baseUri.resolve(path), headers: headers) : await _client.post(baseUri.resolve(path), headers: headers, body: body == null ? null : jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException(response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Expected a JSON object');
    return decoded;
  }
}

/// 응답 내용을 노출하지 않고 HTTP 상태를 전달한다.
class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;
}
