import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/app_router.dart';
import 'package:spending_tracker/design_system/tokens.dart';
import 'package:spending_tracker/main.dart';
import 'package:spending_tracker/onboarding/onboarding_page.dart';
import 'package:spending_tracker/splash/splash_page.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/data/users/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashFakeAuth implements AuthService {
  @override
  String? get currentEmail => 'user@example.com';
  bool signedIn = false;
  bool fails = false;
  final Object sessionIdentity = Object();
  @override
  Object? get currentSessionIdentity => signedIn ? sessionIdentity : null;
  @override
  String? get currentUserId => signedIn ? 'user' : null;
  @override
  bool get hasCurrentUsableSession => signedIn;
  @override
  Future<bool> hasUsableSession() async {
    if (fails) throw StateError('network');
    return signedIn;
  }
  @override
  Future<bool> refreshUsableSession() async => signedIn;
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
}

class SplashFakeUsers implements UserRepository {
  @override
  Future<void> completeOnboarding(String nickname) async {}
  @override
  Future<String> getNicknameSuggestion() async => 'Mellow Otter';
  Completer<UserBootstrapResult>? pending;
  bool fails = false;
  bool onboardingRequired = false;
  int calls = 0;
  @override
  Future<UserBootstrapResult> bootstrap() async {
    calls++;
    if (fails) throw StateError('network');
    return pending == null ? UserBootstrapResult(userId: 'user', onboardingRequired: onboardingRequired) : pending!.future;
  }
}

/// 스플래시와 다음 화면 사이의 이동을 확인한다.
GoRouter splashRouter() => GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/', name: 'home', builder: (_, _) => const Scaffold(body: Text('Home'))),
    GoRoute(path: '/signup', name: 'signup', builder: (_, _) => const Scaffold(body: Text('Signup'))),
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
  late SplashFakeAuth auth;
  late SplashFakeUsers users;
  late AuthService oldAuth;
  late UserRepository oldUsers;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    oldAuth = AuthService.instance;
    oldUsers = UserRepository.instance;
    auth = SplashFakeAuth();
    users = SplashFakeUsers();
    AuthService.instance = auth;
    UserRepository.instance = users;
  });
  tearDown(() { AuthService.instance = oldAuth; UserRepository.instance = oldUsers; });

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
    await tester.pump(const Duration(milliseconds: 19));
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

  // 회원 세션은 서버 초기화가 끝나기 전 홈으로 이동하지 않는다.
  testWidgets('회원은 bootstrap 완료 후 홈으로 이동한다', (tester) async {
    auth.signedIn = true;
    users.pending = Completer<UserBootstrapResult>();
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    users.pending!.complete(const UserBootstrapResult(userId: 'user', onboardingRequired: false));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(users.calls, 1);
  });

  testWidgets('가입 정보가 필요한 회원은 재실행 후 가입 화면으로 이동한다', (tester) async {
    auth.signedIn = true;
    users.onboardingRequired = true;
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Signup'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  // 초기화 오류는 로그아웃 처리하지 않고 같은 경로에서 재시도한다.
  testWidgets('서버 오류 후 재시도하면 홈으로 이동한다', (tester) async {
    auth.signedIn = true;
    users.fails = true;
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
    users.fails = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(users.calls, 2);
  });

  // 세션 확인 중 네트워크 오류는 온보딩이나 로그아웃으로 처리하지 않는다.
  testWidgets('세션 확인 오류는 재시도 후 다시 판단한다', (tester) async {
    auth.fails = true;
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
    expect(users.calls, 0);
    auth.fails = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding'), findsOneWidget);
  });

  // 비회원 초기화에서 온보딩으로 이동하면 이전 경로가 뒤로가기에 남지 않는다.
  testWidgets('온보딩으로 이동한 뒤 이전 화면으로 돌아가지 않는다', (tester) async {
    final router = splashRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/other');
    await tester.pumpAndSettle();
    router.push('/splash');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding'), findsOneWidget);
    expect(router.canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Other'), findsNothing);
  });

  // 직접 홈 주소로 들어와도 회원의 초기화 성공 전에는 홈을 만들지 않는다.
  testWidgets('직접 홈 진입은 회원 bootstrap을 기다리고 중복 호출하지 않는다', (tester) async {
    auth.signedIn = true;
    users.pending = Completer<UserBootstrapResult>();
    appRouter.go('/');
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('Spent this month'), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    users.pending!.complete(const UserBootstrapResult(userId: 'user', onboardingRequired: false));
    await tester.pumpAndSettle();
    expect(find.text('Spent this month'), findsOneWidget);
    expect(users.calls, 1);
  });

  // 직접 홈 진입 시 세션이 없으면 온보딩 경로가 스택을 대체한다.
  testWidgets('직접 홈 진입은 세션이 없으면 온보딩으로 이동한다', (tester) async {
    appRouter.go('/');
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    image.frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 149, false);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    tester.widget<Image>(find.byType(Image)).frameBuilder!(tester.element(find.byType(Image)), const SizedBox(), 0, false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(appRouter.canPop(), isFalse);
    expect(users.calls, 0);
  });
}
