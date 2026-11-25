import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar.dart';
import 'package:spending_tracker/calendar/calendar_access.dart';
import 'package:spending_tracker/data/ledgers/ledger_repository.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/home/home_format.dart';
import 'package:spending_tracker/home/home_page.dart';
import 'support/calendar_fixtures.dart';

void main() {
  testWidgets('회원 달력을 스와이프하면 캐시된 기간으로 이동한다', (tester) async {
    SharedPreferences.setMockInitialValues({'home_add_tooltip_seen': true});
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = CalendarAccess.instance;
    final source = FakeCalendarDataSource();
    source.loader = (request) async {
      final date = request.anchorDate;
      final start = DateTime.utc(date.year, date.month);
      final next = DateTime.utc(date.year, date.month + 1);
      return CalendarPeriod.fromJson(calendarJson(start: calendarDateKey(start), end: calendarDateKey(next.subtract(const Duration(days: 1))), previous: calendarDateKey(start.subtract(const Duration(days: 1))), next: calendarDateKey(next)));
    };
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((request) async => request.url.path == '/categories' ? http.Response('[]', 200) : http.Response('[{"id":"personal","name":"Personal"}]', 200)));
    CalendarAccess.instance = CalendarAccess(ledgers: LedgerRepository(api), dataSource: source);
    addTearDown(() { CalendarAccess.instance = old; api.close(); });
    await tester.pumpWidget(const MaterialApp(home: HomePage(isMember: true)));
    await tester.pumpAndSettle();
    expect(source.requests.length, 3);
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + 1);
    await tester.timedDrag(find.byType(AppCalendarPager), const Offset(-260, 0), const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('${homeMonths[target.month - 1]} ${target.year}'), findsOneWidget);
    expect(source.requests.length, 4);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('인접 기간 조회가 늦으면 현재 달력을 유지하다가 이동한다', (tester) async {
    SharedPreferences.setMockInitialValues({'home_add_tooltip_seen': true});
    final old = CalendarAccess.instance;
    final source = FakeCalendarDataSource();
    final gate = Completer<CalendarPeriod>();
    final now = DateTime.now();
    final next = DateTime.utc(now.year, now.month + 1);
    CalendarPeriod makePeriod(DateTime date) {
      final start = DateTime.utc(date.year, date.month);
      final end = DateTime.utc(date.year, date.month + 1);
      return CalendarPeriod.fromJson(calendarJson(start: calendarDateKey(start), end: calendarDateKey(end.subtract(const Duration(days: 1))), previous: calendarDateKey(start.subtract(const Duration(days: 1))), next: calendarDateKey(end)));
    }
    source.loader = (request) => request.anchorDate == next ? gate.future : Future.value(makePeriod(request.anchorDate));
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((request) async => request.url.path == '/categories' ? http.Response('[]', 200) : http.Response('[{"id":"personal","name":"Personal"}]', 200)));
    CalendarAccess.instance = CalendarAccess(ledgers: LedgerRepository(api), dataSource: source);
    addTearDown(() { CalendarAccess.instance = old; api.close(); });
    await tester.pumpWidget(const MaterialApp(home: HomePage(isMember: true)));
    await tester.pumpAndSettle();
    await tester.timedDrag(find.byType(AppCalendarPager), const Offset(-260, 0), const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('${homeMonths[now.month - 1]} ${now.year}'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(source.requests.where((request) => request.anchorDate == next).length, 1);
    gate.complete(makePeriod(next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('${homeMonths[next.month - 1]} ${next.year}'), findsOneWidget);
  });
}
