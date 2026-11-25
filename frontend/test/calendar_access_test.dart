import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar_access.dart';
import 'package:spending_tracker/calendar/http_calendar_data_source.dart';
import 'package:spending_tracker/data/ledgers/ledger_repository.dart';

import 'support/calendar_fixtures.dart';

void main() {
  test('인증된 가계부 ID로 실제 달력 API 경로를 조회한다', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['authorization'], 'Bearer token');
      if (request.url.path == '/ledgers') return http.Response('[{"id":"personal","name":"Personal"}]', 200);
      expect(request.url.queryParameters['anchor_date'], isNotEmpty);
      return http.Response(jsonEncode(calendarJson()), 200);
    });
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: client);
    final access = CalendarAccess(ledgers: LedgerRepository(api), dataSource: HttpCalendarDataSource(api));
    final controller = await access.open();
    addTearDown(controller.dispose);
    expect(paths, ['/ledgers', '/ledgers/personal/calendar']);
    expect(controller.ledgerId, 'personal');
    expect(controller.state.period, isNotNull);
    expect(controller.state.error, isNull);
  });

  test('가계부 목록 실패를 빈 달력으로 바꾸지 않는다', () async {
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((_) async => http.Response('{}', 503)));
    final access = CalendarAccess(ledgers: LedgerRepository(api), dataSource: HttpCalendarDataSource(api));
    await expectLater(access.open(), throwsA(isA<ApiException>()));
  });

  test('달력 서버 오류는 상태에 보존한다', () async {
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((request) async => request.url.path == '/ledgers' ? http.Response('[{"id":"personal","name":"Personal"}]', 200) : http.Response('{}', 503)));
    final access = CalendarAccess(ledgers: LedgerRepository(api), dataSource: HttpCalendarDataSource(api));
    final controller = await access.open();
    addTearDown(controller.dispose);
    expect(controller.state.error, isA<ApiException>());
    expect(controller.state.period, isNull);
  });
}
