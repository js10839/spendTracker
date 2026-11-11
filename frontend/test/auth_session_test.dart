import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 테스트용 만료 시각을 가진 JWT 형태의 세션을 만든다.
String sessionJson(DateTime expiry) {
  String encode(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token': '${encode({'alg': 'none'})}.${encode({'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.signature',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': {'id': 'test-user', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}, 'aud': 'authenticated', 'created_at': '2026-01-01T00:00:00Z'},
  });
}

void main() {
  test('저장된 세션이 없으면 로그인되지 않은 상태다', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test-key');
    addTearDown(client.dispose);
    expect(await SupabaseAuthService(client).hasUsableSession(), isFalse);
  });

  test('유효한 복원 세션은 갱신 요청 없이 사용할 수 있다', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.supabase.co', 'test-key', httpClient: MockClient((_) async { requests++; return http.Response('', 500); }));
    addTearDown(client.dispose);
    await client.auth.setInitialSession(sessionJson(DateTime.now().add(const Duration(hours: 1))));
    expect(await SupabaseAuthService(client).hasUsableSession(), isTrue);
    expect(requests, 0);
  });

  test('만료된 세션의 무효한 refresh token은 로그인되지 않은 상태로 처리한다', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test-key', httpClient: MockClient((_) async => http.Response('{"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}', 400, headers: {'content-type': 'application/json'})));
    addTearDown(client.dispose);
    await client.auth.setInitialSession(sessionJson(DateTime.now().subtract(const Duration(hours: 1))));
    expect(await SupabaseAuthService(client).hasUsableSession(), isFalse);
  });

  test('만료된 세션은 갱신에 성공하면 사용할 수 있다', () async {
    final refreshed = sessionJson(DateTime.now().add(const Duration(hours: 1)));
    final client = SupabaseClient('https://example.supabase.co', 'test-key', httpClient: MockClient((_) async => http.Response(refreshed, 200, headers: {'content-type': 'application/json'})));
    addTearDown(client.dispose);
    await client.auth.setInitialSession(sessionJson(DateTime.now().subtract(const Duration(hours: 1))));
    expect(await SupabaseAuthService(client).hasUsableSession(), isTrue);
  });

  test('일시적인 인증 서버 오류는 로그아웃으로 처리하지 않는다', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test-key', httpClient: MockClient((_) async => http.Response('unavailable', 503)));
    addTearDown(client.dispose);
    await client.auth.setInitialSession(sessionJson(DateTime.now().subtract(const Duration(hours: 1))));
    await expectLater(SupabaseAuthService(client).hasUsableSession(), throwsA(isA<AuthRetryableFetchException>()));
    expect(client.auth.currentSession, isNotNull);
  });
}
