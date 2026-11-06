import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home/home_page.dart';
import 'auth/login_email_page.dart';
import 'auth/login_code_page.dart';
import 'onboarding/onboarding_page.dart';
import 'onboarding/onboarding_cards_page.dart';
import 'onboarding/onboarding_closing_page.dart';
import 'onboarding/onboarding_income_page.dart';
import 'onboarding/onboarding_reminders_page.dart';
import 'onboarding/onboarding_ready_page.dart';
import 'onboarding/onboarding_setting_up_page.dart';
import 'onboarding/onboarding_summary.dart';
import 'onboarding/onboarding_setup_intro_page.dart';
import 'splash/splash_page.dart';

/// 앱의 화면 경로를 한곳에서 관리한다.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
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
      builder: (context, state) => const HomePage(),
    ),
    // TODO: 인증 상태가 준비되면 최초 진입과 로그아웃 시 온보딩을 표시한다.
    GoRoute(
      path: '/login',
      name: 'login-email',
      builder: (context, state) => const LoginEmailPage(),
    ),
    GoRoute(
      path: '/login/code',
      name: 'login-code',
      builder: (context, state) => LoginCodePage(email: state.extra is String ? state.extra as String : ''),
    ),
    GoRoute(
      path: '/onboarding/setup/ready',
      name: 'onboarding-ready',
      builder: (context, state) => const OnboardingReadyPage(),
    ),
    GoRoute(
      path: '/onboarding/setup/reminders',
      name: 'onboarding-reminders',
      builder: (context, state) => OnboardingRemindersPage(summary: state.extra is OnboardingSummary ? state.extra as OnboardingSummary : const OnboardingSummary()),
    ),
    GoRoute(
      path: '/onboarding/setup/setting-up',
      name: 'onboarding-setting-up',
      builder: (context, state) => OnboardingSettingUpPage(summary: state.extra is OnboardingSummary ? state.extra as OnboardingSummary : const OnboardingSummary()),
    ),
    GoRoute(
      path: '/onboarding/setup/income',
      name: 'onboarding-income',
      builder: (context, state) => OnboardingIncomePage(initialStep: state.extra is int ? state.extra as int : 3, cards: state.extra is Map<String, int> ? state.extra as Map<String, int> : const {}),
    ),
    GoRoute(
      path: '/onboarding/setup/closing',
      name: 'onboarding-closing',
      builder: (context, state) => OnboardingClosingPage(cards: (state.extra as List<String>?) ?? const []),
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
