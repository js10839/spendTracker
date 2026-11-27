import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home/home_page.dart';
import 'dashboard/dashboard_page.dart';
import 'dashboard/dashboard_motion.dart';
import 'profile/profile_page.dart';
import 'auth/login_email_page.dart';
import 'auth/login_code_page.dart';
import 'auth/signup_page.dart';
import 'auth/auth_service.dart';
import 'auth/member_bootstrap.dart';
import 'onboarding/onboarding_page.dart';
import 'onboarding/onboarding_cards_page.dart';
import 'onboarding/onboarding_closing_page.dart';
// TODO: 수입 설정 화면을 다시 사용할 때 경로와 함께 복원한다.
// import 'onboarding/onboarding_income_page.dart';
import 'onboarding/onboarding_reminders_page.dart';
import 'onboarding/onboarding_ready_page.dart';
import 'onboarding/onboarding_setting_up_page.dart';
import 'onboarding/onboarding_summary.dart';
import 'onboarding/onboarding_setup_intro_page.dart';
import 'splash/splash_page.dart';

/// 앱의 화면 경로를 한곳에서 관리한다.
// TODO: 공유 딥링크가 추가되면 인증 전 목적지를 보관하고 bootstrap 성공 후 유효한 경로로 복원한다.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/profile',
      name: 'profile',
      redirect: (_, state) =>
          state.extra is bool ? null : _homeRedirect(state.extra),
      builder: (context, state) => ProfilePage(
        isMember: state.extra == true || state.extra is MemberHomeAccess,
        onDashboard: state.extra is bool
            ? null
            : () => context.pushReplacement(
                '/dashboard',
                extra: (access: state.extra, fromHome: false),
              ),
      ),
    ),
    GoRoute(
      path: '/splash',
      name: 'splash',
      // 페이드가 끝날 때까지 스플래시를 같은 위치에 유지한다.
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: splashFadeDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
        child: const SplashPage(),
      ),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      redirect: (context, state) => _homeRedirect(state.extra),
      builder: (context, state) => HomePage(
        isMember: state.extra is MemberHomeAccess,
        onDashboard: () => context.push(
          '/dashboard',
          extra: (access: state.extra, fromHome: true),
        ),
        onProfile: () => context.push('/profile', extra: state.extra),
      ),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      redirect: (_, state) => _homeRedirect(_dashboardAccess(state.extra)),
      pageBuilder: (context, state) {
        final entry = state.extra;
        final access = _dashboardAccess(entry);
        final fromHome =
            entry is ({Object? access, bool fromHome}) && entry.fromHome;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: dashboardDuration(
            context,
            fromHome ? dashboardHomeDuration : dashboardFadeDuration,
          ),
          reverseTransitionDuration: dashboardDuration(
            context,
            dashboardHomeDuration,
          ),
          transitionsBuilder: (_, animation, _, child) => dashboardFade(
            animation,
            child,
            curve: fromHome || animation.status == AnimationStatus.reverse
                ? dashboardEaseInOut
                : dashboardEaseOut,
          ),
          child: DashboardPage(
            isMember: access is MemberHomeAccess,
            onHome: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/', extra: access);
              }
            },
            onProfile: () => context.pushReplacement('/profile', extra: access),
          ),
        );
      },
    ),
    // TODO: 로그아웃 및 앱 사용 중 세션 무효화 시 온보딩으로 이동한다.
    GoRoute(
      path: '/signup',
      name: 'signup',
      redirect: (context, state) {
        final access = state.extra;
        return access is MemberHomeAccess &&
                access.onboardingRequired &&
                access.matchesSession(AuthService.instance)
            ? null
            : '/splash';
      },
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login-email',
      pageBuilder: (context, state) {
        const child = LoginEmailPage();
        if (state.extra != dashboardDetailOrigin) {
          return MaterialPage<void>(key: state.pageKey, child: child);
        }
        final duration = dashboardDuration(context, dashboardFadeDuration);
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (_, animation, _, child) =>
              dashboardFade(animation, child),
          child: child,
        );
      },
    ),
    GoRoute(
      path: '/login/code',
      name: 'login-code',
      builder: (context, state) => LoginCodePage(
        email: state.extra is String ? state.extra as String : '',
      ),
    ),
    GoRoute(
      path: '/onboarding/setup/ready',
      name: 'onboarding-ready',
      builder: (context, state) => const OnboardingReadyPage(),
    ),
    GoRoute(
      path: '/onboarding/setup/reminders',
      name: 'onboarding-reminders',
      builder: (context, state) => OnboardingRemindersPage(
        summary: state.extra is OnboardingSummary
            ? state.extra as OnboardingSummary
            : const OnboardingSummary(),
      ),
    ),
    GoRoute(
      path: '/onboarding/setup/setting-up',
      name: 'onboarding-setting-up',
      builder: (context, state) => OnboardingSettingUpPage(
        summary: state.extra is OnboardingSummary
            ? state.extra as OnboardingSummary
            : const OnboardingSummary(),
      ),
    ),
    // TODO: 수입 설정을 다시 포함할 때 연결한다.
    // GoRoute(path: '/onboarding/setup/income', name: 'onboarding-income',
    //   builder: (context, state) => OnboardingIncomePage(
    //     initialStep: state.extra is int ? state.extra as int : 3,
    //     cards: state.extra is Map<String, int> ? state.extra as Map<String, int> : const {},
    //   ),
    // ),
    GoRoute(
      path: '/onboarding/setup/closing',
      name: 'onboarding-closing',
      builder: (context, state) => OnboardingClosingPage(
        cards: (state.extra as List<String>?) ?? const [],
      ),
    ),
    GoRoute(
      path: '/onboarding/setup/cards',
      name: 'onboarding-cards',
      builder: (context, state) => const OnboardingCardsPage(),
    ),
    GoRoute(
      path: '/onboarding/setup',
      name: 'onboarding-setup',
      builder: (context, state) => const OnboardingSetupIntroPage(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      // 스플래시에서 이동할 때만 페이드를 적용한다.
      pageBuilder: (context, state) {
        if (state.extra != splashExitTransition) {
          return MaterialPage<void>(
            key: state.pageKey,
            child: const OnboardingPage(),
          );
        }
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: splashFadeDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          child: const OnboardingPage(),
        );
      },
    ),
  ],
);

String? _homeRedirect(Object? access) {
  final auth = AuthService.instance;
  if (access is MemberHomeAccess && access.matches(auth)) return null;
  if (access is GuestHomeAccess && auth.currentUserId == null) return null;
  return '/splash';
}

Object? _dashboardAccess(Object? entry) =>
    entry is ({Object? access, bool fromHome}) ? entry.access : entry;
