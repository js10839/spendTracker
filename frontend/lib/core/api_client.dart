import 'package:http/http.dart' as http;

import '../api/api_client.dart' as transport;

/// 기존 회원 API 인터페이스를 공통 HTTP 전송 계층에 연결한다.
class ApiClient {
  ApiClient({required Uri baseUri, required String? Function() accessToken, http.Client? client}) : shared = transport.ApiClient(baseUrl: baseUri, accessToken: accessToken, client: client);

  final transport.ApiClient shared;

  /// 요청 시점의 세션 토큰으로 JSON POST 요청을 보낸다.
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) => _request(path, isGet: false, body: body);

  /// 요청 시점의 세션 토큰으로 JSON GET 요청을 보낸다.
  Future<Map<String, dynamic>> get(String path) => _request(path, isGet: true);

  /// 기존 호출자의 오류 계약과 객체 응답 형식을 유지한다.
  Future<Map<String, dynamic>> _request(String path, {required bool isGet, Map<String, dynamic>? body}) async {
    try {
      final parts = Uri.parse(path).pathSegments.where((part) => part.isNotEmpty).toList();
      final result = isGet ? await shared.getJson(parts) : await shared.postJson(parts, body: body);
      if (result is! Map<String, dynamic>) throw const FormatException('Expected a JSON object');
      return result;
    } on transport.ApiException catch (error) {
      throw ApiException(error.statusCode);
    } on transport.MissingAccessTokenException {
      throw StateError('Authentication required');
    }
  }
}

/// 응답 내용을 노출하지 않고 HTTP 상태를 전달한다.
class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;
}
