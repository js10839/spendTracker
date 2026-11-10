import 'dart:convert';

import 'package:http/http.dart' as http;

/// 인증된 FastAPI 요청과 공통 오류 처리를 담당한다.
class ApiClient {
  ApiClient({required this.baseUri, required this.accessToken, http.Client? client}) : _client = client ?? http.Client();

  final Uri baseUri;
  final String? Function() accessToken;
  final http.Client _client;

  /// 요청 시점의 세션 토큰으로 JSON POST 요청을 보낸다.
  Future<Map<String, dynamic>> post(String path) async {
    final token = accessToken();
    if (token == null || token.isEmpty) throw StateError('Authentication required');
    final response = await _client.post(baseUri.resolve(path), headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException(response.statusCode);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) throw const FormatException('Expected a JSON object');
    return body;
  }
}

/// 응답 내용을 노출하지 않고 HTTP 상태를 전달한다.
class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;
}
