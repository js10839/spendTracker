import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar.dart';

import 'support/calendar_fixtures.dart';

void main() {
  test(
    'one calendar GET sends anchor/card and decodes full day/item detail',
    () async {
      final requests = <http.Request>[];
      final payload = calendarJson(card: 'chase');
      (payload['days'] as List<dynamic>)[19] = detailedDayJson();
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(payload), 200);
      });
      final api = ApiClient(
        baseUrl: Uri.parse('https://backend.example'),
        accessToken: () => 'token',
        client: client,
      );
      addTearDown(api.close);
      final period = await HttpCalendarDataSource(api).loadCalendar(
        ledgerId: 'personal',
        anchorDate: DateTime(2026, 10, 20),
        paymentMethodId: 'chase',
      );
      expect(requests.single.url.path, '/ledgers/personal/calendar');
      expect(requests.single.url.queryParameters, {
        'anchor_date': '2026-10-20',
        'payment_method_id': 'chase',
      });
      expect(requests.single.headers['Authorization'], 'Bearer token');
      final day = period.days[DateTime.utc(2026, 10, 20)]!;
      expect(day.transactions.single.items.single.name, 'Coffee');
      expect(day.transactions.single.taxCents, 50);
      expect(day.dots.single.color, '#1234AB');
      expect(day.income.single.expectedDate, DateTime.utc(2026, 10, 21));
      expect(day.closingCards.single.id, 'other');
      expect(day.note!.content, 'Day note');
      expect(day.spendingCents, 650);
      expect(day.receivedIncomeCents, 0);
      expect(() => period.days.clear(), throwsUnsupportedError);
      expect(() => day.transactions.clear(), throwsUnsupportedError);
    },
  );

  test('server totals are consumed verbatim rather than recalculated', () {
    final payload = detailedDayJson();
    payload['spending_cents'] = -123;
    payload['received_income_cents'] = 999;
    final day = CalendarDay.fromJson(payload);
    expect(day.spendingCents, -123);
    expect(day.receivedIncomeCents, 999);
  });

  test(
    'All omits card filter; note PUT uses existing endpoint and clear body',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: Uri.parse('https://backend.example'),
        accessToken: () => 'token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.method == 'GET' ? jsonEncode(calendarJson()) : 'null',
            200,
          );
        }),
      );
      addTearDown(api.close);
      final source = HttpCalendarDataSource(api);
      await source.loadCalendar(
        ledgerId: 'personal',
        anchorDate: DateTime(2026, 10, 20),
      );
      expect(requests.single.url.queryParameters, {
        'anchor_date': '2026-10-20',
      });
      expect(
        await source.saveNote(
          ledgerId: 'personal',
          date: DateTime(2026, 10, 20),
          content: '',
        ),
        isNull,
      );
      expect(requests.last.method, 'PUT');
      expect(requests.last.url.path, '/ledgers/personal/day-notes/2026-10-20');
      expect(jsonDecode(requests.last.body), {'content': ''});
    },
  );

  test('malformed calendar fields produce FormatException', () async {
    for (final body in ['[]', '{}', '{"start_date":"bad"}']) {
      final api = ApiClient(
        baseUrl: Uri.parse('https://backend.example'),
        accessToken: () => 'token',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        HttpCalendarDataSource(api).loadCalendar(
          ledgerId: 'personal',
          anchorDate: DateTime(2026, 10, 20),
        ),
        throwsFormatException,
      );
      api.close();
    }
  });

  test('controller plus HTTP adapter loads once, selects locally and reloads after save', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: Uri.parse('https://backend.example'),
      accessToken: () => 'token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.method == 'GET' ? jsonEncode(calendarJson()) : 'null',
          200,
        );
      }),
    );
    final controller = CalendarController(
      ledgerId: 'personal',
      dataSource: HttpCalendarDataSource(api),
      clock: () => DateTime(2026, 10, 20),
    );
    addTearDown(() {
      controller.dispose();
      api.close();
    });
    await controller.refresh();
    controller.selectDate(DateTime(2026, 10, 6));
    expect(requests.length, 1);
    expect(await controller.saveSelectedNote(''), isTrue);
    expect(requests.map((r) => r.method), ['GET', 'PUT', 'GET']);
  });

  test('backend failures reach controller and manual retry recovers', () async {
    var attempts = 0;
    final api = ApiClient(
      baseUrl: Uri.parse('https://backend.example'),
      accessToken: () => 'token',
      client: MockClient(
        (_) async => ++attempts == 1
            ? http.Response('{"detail":"Credit card not found"}', 404)
            : http.Response(jsonEncode(calendarJson()), 200),
      ),
    );
    final controller = CalendarController(
      ledgerId: 'personal',
      dataSource: HttpCalendarDataSource(api),
      clock: () => DateTime(2026, 10, 20),
    );
    addTearDown(() {
      controller.dispose();
      api.close();
    });
    await controller.refresh();
    expect(controller.state.error, isA<ApiException>());
    expect(controller.state.days, isEmpty);
    await controller.refresh();
    expect(controller.state.error, isNull);
    expect(controller.state.days.length, 31);
  });
}
