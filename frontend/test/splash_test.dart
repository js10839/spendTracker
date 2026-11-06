import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/app_router.dart';
import 'package:spending_tracker/design_system/tokens.dart';
import 'package:spending_tracker/main.dart';
import 'package:spending_tracker/onboarding/onboarding_page.dart';
import 'package:spending_tracker/splash/splash_page.dart';

/// 스플래시와 다음 화면 사이의 이동을 확인한다.
GoRouter splashRouter() => GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (_, _) => const Scaffold(body: Text('Onboarding')),
    ),
    GoRoute(
      path: '/other',
      builder: (_, _) => const Scaffold(body: Text('Other')),
    ),
  ],
);

void main() {
  // 실제 앱 경로에서 이전 화면 위로 온보딩이 서서히 나타나는지 확인한다.
  testWidgets('스플래시에서 온보딩으로 페이드 전환', (tester) async {
    appRouter.go('/splash');
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox(),
      149,
      false,
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsOneWidget);
    final fade = find
        .ancestor(
          of: find.byType(OnboardingPage),
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(
      tester.widget<FadeTransition>(fade).opacity.value,
      closeTo(0.5, 0.05),
    );
    await tester.pump(const Duration(milliseconds: 125));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
  });

  // 재생이 늦어져도 마지막 화면을 원본 프레임 길이만큼 표시한 뒤 이동한다.
  testWidgets('스플래시 재생 후 온보딩으로 이동', (tester) async {
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppTokens.splashBackground,
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, const AssetImage('assets/branding/splash.gif'));
    expect(image.fit, BoxFit.cover);

    image.frameBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox(),
      148,
      false,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(SplashPage), findsOneWidget);

    image.frameBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox(),
      149,
      false,
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage('assets/branding/splash_final.png'),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 29));
    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Onboarding'), findsOneWidget);
  });

  // 스플래시에서 먼저 벗어나면 예약된 화면 이동이 실행되지 않는다.
  testWidgets('화면 이탈 시 스플래시 타이머 취소', (tester) async {
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(
      tester.element(find.byType(Image)),
      const SizedBox(),
      149,
      false,
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
    router.go('/other');
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
  });
}
