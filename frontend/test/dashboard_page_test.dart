import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/app_router.dart';
import 'package:spending_tracker/auth/member_bootstrap.dart';
import 'package:spending_tracker/dashboard/dashboard_page.dart';
import 'package:spending_tracker/dashboard/dashboard_repository.dart';
import 'package:spending_tracker/dashboard/dashboard_preview_data.dart';
import 'package:spending_tracker/home/home_format.dart';
import 'package:spending_tracker/design_system/bottom_navigation.dart';
import 'package:spending_tracker/design_system/page_indicator.dart';
import 'package:spending_tracker/main.dart';

void main() {
  testWidgets(
    'Dashboard opens from Home and shows a swipeable statement carousel',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      appRouter.go('/', extra: const GuestHomeAccess());
      await tester.pumpWidget(const SpendingTrackerApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      final nav = find.byType(AppBottomNavigation);
      expect(tester.widget<AppBottomNavigation>(nav).selectedIndex, 1);
      expect(
        find.text(
          formatHomeMoney(
            dashboardGuestSummary(DateTime(2026, 8)).monthlySpendingCents,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Statement so far · Cycle 8/6 – 9/5'), findsOneWidget);

      final carousel = find.byKey(const Key('dashboard-statement-carousel'));
      final indicator = find.byType(AppPageIndicator);
      await tester.timedDrag(
        carousel,
        const Offset(-300, 0),
        const Duration(milliseconds: 350),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppPageIndicator>(indicator).activeIndex, 1);
      expect(find.text(r'$96.20'), findsOneWidget);

      await tester.tap(find.text('Amex'));
      await tester.pumpAndSettle();
      expect(find.text('Cycle 8/16 – 9/15'), findsOneWidget);
      await tester.tapAt(const Offset(8, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppBottomNavigation>(nav).selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Dashboard changes chart resolution, period and cash month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(isMember: false, onHome: () {}, onProfile: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aug 2026'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('23'), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Jan'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Jul 2026'), findsOneWidget);
    expect(find.text(r'$812.45'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('Aug 2026'), findsOneWidget);

    await tester.ensureVisible(find.text('Net by month'));
    await tester.pumpAndSettle();
    expect(find.text(r'−$45.00'), findsOneWidget);
    await tester.ensureVisible(find.text('Mar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(find.text(r'+$657.80'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Period pills resize and restore the applied month', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(isMember: false, onHome: () {}, onProfile: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('Jul 2026'), findsOneWidget);
    final rollingPill = find.byKey(const Key('dashboard-rolling-pill'));
    final monthPill = find.byKey(const Key('dashboard-month-pill'));
    final collapsed = tester.getSize(rollingPill).width;
    final expanded = tester.getSize(monthPill).width;

    await tester.tap(find.byTooltip('Show past 30 days'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    expect(
      tester.getSize(rollingPill).width,
      inExclusiveRange(collapsed, expanded),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(rollingPill).width, closeTo(expanded, .1));
    expect(
      find.text('Past 30 days (Jul 26 – Aug 24)', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('7/26'), findsOneWidget);

    await tester.tap(find.byTooltip('Show calendar month'));
    await tester.pumpAndSettle();
    expect(tester.getSize(rollingPill).width, closeTo(collapsed, .1));
    expect(find.text('Jul 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Rolling periods combine three calendar months and keep signed totals',
    () async {
      final requests = <String>[];
      final api = ApiClient(
        baseUrl: Uri.parse('https://example.com'),
        accessToken: () => 'test-token',
        client: MockClient((request) async {
          if (request.url.path == '/ledgers') {
            return http.Response('[{"id":"personal","name":"Personal"}]', 200);
          }
          final query = request.url.queryParameters;
          final month = query['month']!;
          requests.add(month);
          if (month == '2026-03-01') {
            expect(query['category_start'], '2026-01-31');
            expect(query['category_end'], '2026-03-01');
          }
          Map<String, Object> day(String date, int amount) => {
            'date': date,
            'total_cents': amount,
            'payment_methods': [
              {
                'payment_method_id': 'card',
                'name': 'Card',
                'color': '#5AD4FC',
                'total_cents': amount,
              },
            ],
          };
          final buckets = switch (month) {
            '2026-01-01' => [day('2026-01-30', 9900), day('2026-01-31', 1000)],
            '2026-02-01' => [day('2026-02-01', -300)],
            _ => [day('2026-03-01', 100), day('2026-03-02', 0)],
          };
          return http.Response(
            jsonEncode({
              'spending_30_days': {'total_cents': 800},
              'payment_method_breakdown': {'total_cents': 100},
              'monthly_spending': {'buckets': buckets},
              'yearly_spending': {'buckets': []},
              'category_breakdown': {
                'categories': [
                  {'name': 'Refund', 'amount_cents': -300},
                ],
              },
              'card_statements': [],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final period = await DashboardRepository(api)
          .loadPast30Days(DateTime(2026, 3, 1));
      expect(
        requests,
        unorderedEquals(['2026-01-01', '2026-02-01', '2026-03-01']),
      );
      expect(period.daily.map((day) => day.cents), [1000, -300, 100]);
      expect(period.paymentMethods.single.cents, 800);
      expect(period.rollingSpendingCents, 800);
      expect(period.categories.single.cents, -300);
    },
  );

  test(
    'Dashboard uses the month breakdown total and card cycle dates',
    () async {
      final api = ApiClient(
        baseUrl: Uri.parse('https://example.com'),
        accessToken: () => 'test-token',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer test-token');
          if (request.url.path == '/ledgers') {
            return http.Response('[{"id":"personal","name":"Personal"}]', 200);
          }
          expect(request.url.path, '/ledgers/personal/dashboard');
          expect(request.url.queryParameters, {
            'as_of': '2026-08-24',
            'month': '2026-08-01',
            'year': '2026',
          });
          return http.Response('''
          {"spending_30_days":{"total_cents":54000},
           "payment_method_breakdown":{"total_cents":5678,"payment_methods":[]},
           "monthly_spending":{"buckets":[{"date":"2026-08-24","total_cents":5678}]},
           "yearly_spending":{"buckets":[{"date":"2026-08-01","total_cents":5678}]},
           "category_breakdown":{"categories":[{"name":"Refund","amount_cents":-500}]},
           "card_statements":[{"name":"Amex","color":"#5AD4FC","total_cents":9620,
             "start_date":"2026-08-16","end_date":"2026-09-15",
             "spent_through":"2026-08-24","top_categories":[]}]}
          ''', 200);
        }),
      );
      addTearDown(api.close);

      final dashboard = await DashboardRepository(api)
          .load(DateTime(2026, 8, 24), month: DateTime(2026, 8, 1));
      expect(dashboard.monthlySpendingCents, 5678);
      expect(dashboard.statements.single.totalCents, 9620);
      expect(dashboard.statements.single.end, DateTime.utc(2026, 9, 15));
      expect(dashboard.daily.single.cents, 5678);
      expect(dashboard.categories.single.cents, -500);
    },
  );
}
