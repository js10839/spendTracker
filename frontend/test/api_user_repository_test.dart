import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/core/api_client.dart';
import 'package:spending_tracker/data/users/user_repository.dart';

void main() {
  test('bootstrap 요청은 현재 토큰과 실제 응답 계약을 사용한다', () async {
    var token = 'first';
    final headers = <String?>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.example.com/users/me/bootstrap');
      headers.add(request.headers['authorization']);
      return http.Response('{"user_id":"user-id"}', 200);
    });
    final repo = ApiUserRepository(ApiClient(baseUri: Uri.parse('https://api.example.com/'), accessToken: () => token, client: client));
    expect(await repo.bootstrap(), 'user-id');
    token = 'refreshed';
    await repo.bootstrap();
    expect(headers, ['Bearer first', 'Bearer refreshed']);
  });

  test('서버 오류는 성공으로 처리하지 않는다', () async {
    final client = MockClient((_) async => http.Response('{"detail":"error"}', 500));
    final repo = ApiUserRepository(ApiClient(baseUri: Uri.parse('https://api.example.com/'), accessToken: () => 'token', client: client));
    await expectLater(repo.bootstrap(), throwsA(isA<ApiException>()));
  });
}
