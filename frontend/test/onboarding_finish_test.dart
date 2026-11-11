import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/auth/member_bootstrap.dart';
import 'package:spending_tracker/data/users/user_repository.dart';
import 'package:spending_tracker/onboarding/onboarding_ready_page.dart';
import 'package:spending_tracker/onboarding/onboarding_reminders_page.dart';
import 'package:spending_tracker/onboarding/onboarding_setting_up_page.dart';
import 'package:spending_tracker/onboarding/onboarding_summary.dart';
import 'package:spending_tracker/onboarding/widgets/onboarding_animation.dart';

class ReadyAuth implements AuthService {
  final session = Object();
  @override
  String? get currentUserId => 'user';
  @override
  String? get currentEmail => null;
  @override
  Object get currentSessionIdentity => session;
  @override
  bool get hasCurrentUsableSession => true;
  @override
  Future<bool> hasUsableSession() async => true;
  @override
  Future<bool> refreshUsableSession() async => true;
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
}

class ReadyUsers implements UserRepository {
  bool fails = true;
  @override
  Future<UserBootstrapResult> bootstrap() async {
    if (fails) throw StateError('network');
    return const UserBootstrapResult(userId: 'user', onboardingRequired: false);
  }
  @override
  Future<String> getNicknameSuggestion() async => '';
  @override
  Future<void> completeOnboarding(String nickname) async {}
}

void main() {
  testWidgets('회원 초기화가 실패하면 완료 화면에서 재시도해 홈으로 이동한다', (tester) async {
    final previousAuth = AuthService.instance;
    final previousUsers = UserRepository.instance;
    final users = ReadyUsers();
    AuthService.instance = ReadyAuth();
    UserRepository.instance = users;
    addTearDown(() { AuthService.instance = previousAuth; UserRepository.instance = previousUsers; });
    Object? access;
    final router = GoRouter(initialLocation: '/ready', routes: [
      GoRoute(path: '/ready', builder: (_, _) => const OnboardingReadyPage()),
      GoRoute(path: '/home', name: 'home', builder: (_, state) { access = state.extra; return const Scaffold(body: Text('Home')); }),
      GoRoute(path: '/login', name: 'login-email', builder: (_, _) => const Scaffold(body: Text('Login'))),
      GoRoute(path: '/signup', name: 'signup', builder: (_, _) => const Scaffold(body: Text('Signup'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).onComplete!();
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    users.fails = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(access, isA<MemberHomeAccess>());
  });

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
