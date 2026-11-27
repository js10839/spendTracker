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
    await tester.tap(find.byTooltip('Back to this month'));
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
