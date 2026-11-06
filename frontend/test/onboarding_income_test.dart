import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/design_system/closing_day_picker.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/onboarding/onboarding_cards_page.dart';
import 'package:spending_tracker/onboarding/onboarding_closing_page.dart';
import 'package:spending_tracker/onboarding/onboarding_income_page.dart';
import 'package:spending_tracker/onboarding/onboarding_summary.dart';

void main() {
  testWidgets('수입 주기와 날짜를 선택하고 전환 시 초기화한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: OnboardingIncomePage()));
    expect(find.byType(AppDaySelectionGrid), findsNothing);
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await tester.tap(find.text('Twice a month'));
    await tester.pump();
    for (final day in [5, 14, 28]) {
      await tester.tap(find.byKey(ValueKey('income-day-$day')));
      await tester.pump();
    }
    expect(
      tester
          .widget<AppDaySelectionTile>(
            find.byKey(const ValueKey('income-day-5')),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<AppDaySelectionTile>(
            find.byKey(const ValueKey('income-day-14')),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Every 14th and 28th'), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Weekly'));
    await tester.pump();
    expect(find.text('Mon'), findsOneWidget);
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await tester.tap(find.text('Fri'));
    await tester.pump();
    expect(find.text('Every Friday'), findsOneWidget);
    await tester.tap(find.text('Twice a month'));
    await tester.pump();
    expect(find.text('Pick two days your money usually lands'), findsOneWidget);
    await tester.tap(find.text('Irregular'));
    await tester.pump();
    expect(find.byType(AppDaySelectionGrid), findsNothing);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('카드 설정을 건너뛰면 수입 화면으로 간다', (tester) async {
    final router = GoRouter(
      initialLocation: '/cards',
      routes: [
        GoRoute(
          path: '/cards',
          name: 'onboarding-cards',
          builder: (_, _) => const OnboardingCardsPage(),
        ),
        GoRoute(
          path: '/closing',
          name: 'onboarding-closing',
          builder: (_, state) =>
              OnboardingClosingPage(cards: state.extra as List<String>),
        ),
        GoRoute(
          path: '/income',
          name: 'onboarding-income',
          builder: (_, _) => const OnboardingIncomePage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingIncomePage), findsOneWidget);
  });

  testWidgets('선택한 수입과 카드 정보를 다음 화면에 전달한다', (tester) async {
    OnboardingSummary? captured;
    final router = GoRouter(
      initialLocation: '/income',
      routes: [
        GoRoute(
          path: '/income',
          builder: (_, _) => const OnboardingIncomePage(cards: {'Chase': 5}),
        ),
        GoRoute(
          path: '/reminders',
          name: 'onboarding-reminders',
          builder: (_, state) {
            captured = state.extra as OnboardingSummary;
            return const Scaffold(body: Text('Reminder preview'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('income-day-14')));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(captured?.cards, {'Chase': 5});
    expect(captured?.income, 'Payday · every 14th');
  });

  testWidgets('카드 마감일 설정 완료 후 수입 화면으로 간다', (tester) async {
    final router = GoRouter(
      initialLocation: '/closing',
      routes: [
        GoRoute(
          path: '/closing',
          name: 'onboarding-closing',
          builder: (_, _) => const OnboardingClosingPage(cards: ['Chase']),
        ),
        GoRoute(
          path: '/income',
          name: 'onboarding-income',
          builder: (_, _) => const OnboardingIncomePage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(const ValueKey('closing-day-5')));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingIncomePage), findsOneWidget);
  });

  testWidgets('단계 이동과 되돌아가기는 이전 진행률에서 시작한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/cards',
      routes: [
        GoRoute(
          path: '/cards',
          name: 'onboarding-cards',
          builder: (_, _) => const OnboardingCardsPage(),
        ),
        GoRoute(
          path: '/income',
          name: 'onboarding-income',
          builder: (_, state) =>
              OnboardingIncomePage(initialStep: state.extra as int),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator).last,
          )
          .value,
      closeTo(0.8, 0.001),
    );
    router.pop();
    await tester.pumpAndSettle();
    final bar = tester.widget<AppProgress>(find.byType(AppProgress));
    expect(bar.initialStep, 4);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.4, 0.001),
    );
  });

  testWidgets('작은 화면의 월 2회 선택', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: OnboardingIncomePage()));
    await tester.tap(find.text('Twice a month'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('income-day-31')));
    await tester.tap(find.byKey(const ValueKey('income-day-31')));
    await tester.pump();
    expect(find.text('Every 31st and …'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
