import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/onboarding/onboarding_ready_page.dart';
import 'package:spending_tracker/onboarding/onboarding_reminders_page.dart';
import 'package:spending_tracker/onboarding/onboarding_setting_up_page.dart';
import 'package:spending_tracker/onboarding/onboarding_summary.dart';
import 'package:spending_tracker/onboarding/widgets/onboarding_animation.dart';

void main() {
  testWidgets('온보딩 GIF가 표시되고 완료 후 홈으로 이동한다', (tester) async {
    const summary = OnboardingSummary(cards: {'Chase': 5}, income: 'Payday · every 14th');
    final router = GoRouter(initialLocation: '/reminders', routes: [
      GoRoute(path: '/', name: 'home', builder: (_, _) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/reminders', name: 'onboarding-reminders', builder: (_, _) => const OnboardingRemindersPage(summary: summary)),
      GoRoute(path: '/setting', name: 'onboarding-setting-up', builder: (_, state) => OnboardingSettingUpPage(summary: state.extra as OnboardingSummary)),
      GoRoute(path: '/ready', name: 'onboarding-ready', builder: (_, _) => const OnboardingReadyPage()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).asset, 'assets/onboarding/reminder.gif');
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).asset, 'assets/onboarding/setup.gif');
    tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).onComplete!();
    await tester.pumpAndSettle();
    expect(find.text('Let’s start!'), findsOneWidget);
    expect(tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).asset, 'assets/onboarding/ready-check.gif');
    expect(tester.getCenter(find.byType(OnboardingAnimation)).dx, closeTo(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, 0.01));
    tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).onComplete!();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
