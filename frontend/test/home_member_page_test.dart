import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar.dart';
import 'package:spending_tracker/calendar/calendar_access.dart';
import 'package:spending_tracker/data/ledgers/ledger_repository.dart';
import 'package:spending_tracker/home/home_page.dart';

import 'support/calendar_fixtures.dart';

void main() {
  testWidgets('회원 홈에서 카드 사이클과 Cash 필터를 서버 ID로 조회한다', (tester) async {
    SharedPreferences.setMockInitialValues({'home_add_tooltip_seen': true});
    final oldAccess = CalendarAccess.instance;
    final source = FakeCalendarDataSource();
    final patches = <String>[];
    final searches = <Uri>[];
    var secondMemo = 'Second note';
    source.loader = (request) async {
      if (request.paymentMethodId == 'chase') {
        return CalendarPeriod.fromJson(calendarJson(start: '2026-10-13', end: '2026-11-12', card: 'chase'));
      }
      final json = calendarJson(card: request.paymentMethodId);
      if (request.paymentMethodId == 'cash') json['mode'] = 'cash';
      if (request.paymentMethodId == null) {
        final day = detailedDayJson();
        day['received_income_cents'] = 12000;
        final original = (day['transactions'] as List).first as Map<String, dynamic>;
        (day['transactions'] as List).add({...original, 'id': 'second', 'memo': secondMemo});
        (json['days'] as List)[19] = day;
      }
      return CalendarPeriod.fromJson(json);
    };
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((request) async {
      if (request.url.path.endsWith('/transactions/search')) {
        searches.add(request.url);
        return http.Response(jsonEncode({'matched_dates': ['2026-10-20'], 'item_count': 1, 'store_count': 1, 'matched_items_total_cents': 500, 'items': [{'item_id': 'coffee', 'transaction_id': 'purchase', 'name': 'Coffee', 'merchant': 'Cafe', 'category_id': 'dining', 'category_name': 'Dining', 'transacted_at': '2026-10-20', 'amount_cents': 500, 'matched_fields': ['item']}]}), 200);
      }
      if (request.method == 'PATCH') {
        patches.add(request.url.path);
        secondMemo = (jsonDecode(request.body) as Map<String, dynamic>)['memo'] as String;
        return http.Response(jsonEncode({'id': 'second', 'memo': secondMemo}), 200);
      }
      return request.url.path == '/categories' ? http.Response('[{"id":"dining","name":"Dining"}]', 200) : http.Response('[{"id":"personal","name":"Personal"}]', 200);
    }));
    CalendarAccess.instance = CalendarAccess(ledgers: LedgerRepository(api), dataSource: source);
    addTearDown(() => CalendarAccess.instance = oldAccess);
    await tester.pumpWidget(const MaterialApp(home: HomePage(isMember: true)));
    await tester.pumpAndSettle();
    expect(find.text('\$812.45'), findsNothing);
    expect(source.requests.last.paymentMethodId, isNull);
    expect(find.text('Unable to load your calendar.'), findsNothing);
    final total = find.byKey(const Key('home-total-amount'));
    expect(find.descendant(of: total, matching: find.text('\$6.50')), findsOneWidget);
    await tester.tap(total);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byKey(const Key('home-search-field')), matching: find.byType(TextField)), 'Coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(searches.single.queryParameters, {'query': 'Coffee', 'start_date': '2026-10-01', 'end_date': '2026-10-31'});
    expect(find.text('1 days with “Coffee”'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: total, matching: find.text('\$113.50')), findsOneWidget);
    await tester.tap(total);
    await tester.pumpAndSettle();
    expect(find.descendant(of: total, matching: find.text('\$120.00')), findsOneWidget);
    await tester.tap(total);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-day-2026-10-20')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-merchant-0-Cafe')));
    await tester.tap(find.byKey(const Key('home-merchant-0-Cafe')));
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
    expect(find.text('Receipt note'), findsOneWidget);
    await tester.ensureVisible(find.text('Second note'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('home-note-input')), 'Updated second');
    await tester.tap(find.byKey(const Key('home-note-save')));
    await tester.pumpAndSettle();
    expect(patches, ['/ledgers/personal/transactions/second/memo']);
    expect(find.text('Updated second'), findsOneWidget);
    expect(find.text('Receipt note'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-filter-option-1')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(source.requests.last.paymentMethodId, 'chase');
    expect(find.descendant(of: total, matching: find.text('\$0.00')), findsOneWidget);
    expect(find.byKey(const Key('home-day-2026-10-13')), findsOneWidget);
    expect(find.byKey(const Key('home-day-2026-11-12')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-filter-option-2')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(source.requests.last.paymentMethodId, 'cash');
    expect(find.text('Payday'), findsNothing);
    await tester.tap(total);
    await tester.tap(total);
    await tester.pumpAndSettle();
    expect(find.descendant(of: total, matching: find.text('\$0.00')), findsOneWidget);
  });
}
