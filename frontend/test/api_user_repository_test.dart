import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/core/api_client.dart';
import 'package:spending_tracker/data/users/user_repository.dart';

void main() {
  test('가입 정보 완료 요청에 선택한 이름을 전달한다', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/users/me/onboarding/complete');
      expect(request.headers['authorization'], 'Bearer token');
      expect(request.headers['content-type'], contains('application/json'));
      expect(request.body, '{"nickname":"Calm Otter"}');
      return http.Response('{"id":"user","nickname":"Calm Otter","plan":"free"}', 200);
    });
    final repo = ApiUserRepository(ApiClient(baseUri: Uri.parse('https://api.example.com/'), accessToken: () => 'token', client: client));
    await repo.completeOnboarding('Calm Otter');
  });

  test('이름 후보를 인증된 GET 요청으로 받아온다', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://api.example.com/users/me/nickname-suggestion');
      expect(request.headers['authorization'], 'Bearer token');
      return http.Response('{"nickname":"Calm Otter"}', 200);
    });
    final repo = ApiUserRepository(ApiClient(baseUri: Uri.parse('https://api.example.com/'), accessToken: () => 'token', client: client));
    expect(await repo.getNicknameSuggestion(), 'Calm Otter');
  });

  test('이름 후보 조회 오류와 잘못된 응답을 전달한다', () async {
    for (final response in [http.Response('{}', 200), http.Response('{"nickname":" "}', 200), http.Response('{}', 503)]) {
      final repo = ApiUserRepository(ApiClient(baseUri: Uri.parse('https://api.example.com/'), accessToken: () => 'token', client: MockClient((_) async => response)));
      await expectLater(repo.getNicknameSuggestion(), throwsA(response.statusCode == 503 ? isA<ApiException>() : isA<FormatException>()));
    }
  });

  test('bootstrap 요청은 현재 토큰과 실제 응답 계약을 사용한다', () async {
    var token = 'first';
    final headers = <String?>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.example.com/users/me/bootstrap');
      headers.add(request.headers['authorization']);
      return http.Response('{"user_id":"user-id","onboarding_required":true}', 200);
    });
    final repo = ApiUserRepository(ApiClient(baseUri: Uri.parse('https://api.example.com/'), accessToken: () => token, client: client));
    final result = await repo.bootstrap();
    expect(result.userId, 'user-id');
    expect(result.onboardingRequired, isTrue);
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
