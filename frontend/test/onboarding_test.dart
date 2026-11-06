import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/app_router.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/main.dart';
import 'package:spending_tracker/onboarding/onboarding_page.dart';
import 'package:spending_tracker/auth/login_email_page.dart';
import 'package:spending_tracker/onboarding/onboarding_setup_intro_page.dart';

/// 인증 화면 연결 전 온보딩과 임시 홈 경로를 확인한다.
GoRouter onboardingRouter() => GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (_, _) => const Scaffold(body: Text('Home preview')),
    ),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
    GoRoute(path: '/login', name: 'login-email', builder: (_, _) => const LoginEmailPage()),
    GoRoute(
      path: '/onboarding/setup',
      name: 'onboarding-setup',
      builder: (_, _) => const OnboardingSetupIntroPage(),
    ),
  ],
);

void main() {
  // 진행률이 다음 단계와 이전 단계 사이에서 점진적으로 바뀌는지 확인한다.
  testWidgets('온보딩 진행률 애니메이션', (tester) async {
    final step = ValueNotifier(1);
    addTearDown(step.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: step,
          builder: (context, value, child) => AppProgress(step: value),
        ),
      ),
    );
    double progress() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(progress(), closeTo(1 / 3, 0.001));
    step.value = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), greaterThan(1 / 3));
    expect(progress(), lessThan(2 / 3));
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), closeTo(2 / 3, 0.001));
    step.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), greaterThan(1 / 3));
    expect(progress(), lessThan(2 / 3));
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), closeTo(1 / 3, 0.001));
  });

  // 실제 라우터에서 온보딩 경로를 직접 열 수 있는지 확인한다.
  testWidgets('온보딩 경로 진입', (tester) async {
    expect(appRouter.namedLocation('onboarding-setup'), '/onboarding/setup');
    appRouter.go('/onboarding');
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();
    expect(find.text('Know your card bill'), findsOneWidget);
  });

  // 실제 앱 라우터가 07 설정 안내 경로를 열 수 있는지 확인한다.
  testWidgets('설정 안내 경로 진입', (tester) async {
    appRouter.go('/onboarding/setup');
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();
    expect(find.byType(OnboardingSetupIntroPage), findsOneWidget);
  });

  // Continue, Back과 Skip이 독립적인 세 단계를 유지하는지 확인한다.
  testWidgets('온보딩 화면 전환과 건너뛰기', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = onboardingRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('Know your card bill'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.widget<AppProgress>(find.byType(AppProgress)).step, 1);
    await tester.tap(find.byType(AppBackButton));
    await tester.pump();
    expect(find.text('Know your card bill'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Continue without login'), findsOneWidget);
    final buttonBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('onboarding-continue-3')))
        .dy;
    final linkTop = tester.getTopLeft(find.text('Continue without login')).dy;
    expect(linkTop - buttonBottom, 14);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginEmailPage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your card calendar\nin a minute'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(28));
    final setupButtonBottom = tester
        .getBottomLeft(find.byKey(const Key('onboarding-setup-continue')))
        .dy;
    final setupLinkTop = tester.getTopLeft(find.text("I'll do it later")).dy;
    expect(setupLinkTop - setupButtonBottom, 14);
    expect(
      find.text('By continuing, you agree to the Terms and Privacy Policy'),
      findsOneWidget,
    );
    await tester.tap(find.text("I'll do it later"));
    await tester.pumpAndSettle();
    expect(find.text('Home preview'), findsOneWidget);
  });

  // 로그인 없이 계속해도 동일한 07 안내 화면을 표시한다.
  testWidgets('비로그인 경로에서 설정 안내로 이동', (tester) async {
    final router = onboardingRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.tap(find.text('Continue without login'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingSetupIntroPage), findsOneWidget);
  });

  // 작은 화면에서도 07 화면의 하단 버튼과 링크가 보인다.
  testWidgets('작은 화면에서 설정 안내 확인', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = onboardingRouter();
    addTearDown(router.dispose);
    router.go('/onboarding/setup');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.ensureVisible(find.text("I'll do it later"));
    await tester.pump();
    expect(find.text("Let's go"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 작은 화면에서는 내용을 스크롤할 수 있고 각 단계가 넘치지 않는다.
  testWidgets('작은 화면에서 온보딩 전체 확인', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = onboardingRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    for (var page = 0; page < 3; page++) {
      await tester.ensureVisible(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('Continue without login'));
    await tester.pump();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 세 번째 화면의 눌림 효과가 네 번째 화면의 버튼으로 전달되지 않는다.
  testWidgets('각 화면의 Continue 눌림 상태 분리', (tester) async {
    final router = onboardingRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    for (var page = 0; page < 2; page++) {
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Continue'));
    final previousInk = tester.element(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-continue-2')),
        matching: find.byType(InkWell),
      ),
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    final nextInk = tester.element(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-continue-3')),
        matching: find.byType(InkWell),
      ),
    );
    expect(identical(previousInk, nextInk), isFalse);
    expect(find.text('Continue without login'), findsOneWidget);
  });
}
