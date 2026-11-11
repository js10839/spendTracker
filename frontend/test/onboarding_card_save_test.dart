import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/data/payment_methods/payment_method_repository.dart';
import 'package:spending_tracker/onboarding/onboarding_setting_up_page.dart';
import 'package:spending_tracker/onboarding/onboarding_summary.dart';
import 'package:spending_tracker/onboarding/widgets/onboarding_animation.dart';

class CardSaveAuth implements AuthService {
  @override
  String? get currentUserId => 'user';
  @override
  String? get currentEmail => null;
  @override
  Object? get currentSessionIdentity => null;
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

class CardSaveRepository implements PaymentMethodRepository {
  final calls = <String>[];
  bool failAmex = true;
  @override
  Future<void> createCreditCard({required String name, required int closingDay, required String color}) async {
    calls.add(name);
    if (name == 'Amex' && failAmex) throw StateError('network');
  }
}

class PendingCardRepository implements PaymentMethodRepository {
  final result = Completer<void>();
  @override
  Future<void> createCreditCard({required String name, required int closingDay, required String color}) => result.future;
}

void main() {
  testWidgets('카드가 없으면 애니메이션 완료를 기다리지 않는다', (tester) async {
    final router = GoRouter(initialLocation: '/setting', routes: [
      GoRoute(path: '/setting', builder: (_, _) => const OnboardingSettingUpPage(summary: OnboardingSummary())),
      GoRoute(path: '/ready', name: 'onboarding-ready', builder: (_, _) => const Scaffold(body: Text('Ready'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('애니메이션이 끝나도 카드 저장이 완료될 때까지 기다린다', (tester) async {
    final oldAuth = AuthService.instance;
    final oldRepository = PaymentMethodRepository.instance;
    final repository = PendingCardRepository();
    AuthService.instance = CardSaveAuth();
    PaymentMethodRepository.instance = repository;
    addTearDown(() { AuthService.instance = oldAuth; PaymentMethodRepository.instance = oldRepository; });
    final router = GoRouter(initialLocation: '/setting', routes: [
      GoRoute(path: '/setting', builder: (_, _) => const OnboardingSettingUpPage(summary: OnboardingSummary(cards: {'Chase': 5}))),
      GoRoute(path: '/ready', name: 'onboarding-ready', builder: (_, _) => const Scaffold(body: Text('Ready'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('Chase · closes on the 5th'), findsOneWidget);
    expect(find.textContaining('Payday'), findsNothing);
    tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).onComplete!();
    await tester.pump();
    expect(find.text('Ready'), findsNothing);
    repository.result.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('부분 실패 후 성공한 카드는 다시 저장하지 않는다', (tester) async {
    final oldAuth = AuthService.instance;
    final oldRepository = PaymentMethodRepository.instance;
    final repository = CardSaveRepository();
    AuthService.instance = CardSaveAuth();
    PaymentMethodRepository.instance = repository;
    addTearDown(() { AuthService.instance = oldAuth; PaymentMethodRepository.instance = oldRepository; });
    final router = GoRouter(initialLocation: '/setting', routes: [
      GoRoute(path: '/setting', builder: (_, _) => const OnboardingSettingUpPage(summary: OnboardingSummary(cards: {'Chase': 5, 'Amex': 15}))),
      GoRoute(path: '/ready', name: 'onboarding-ready', builder: (_, _) => const Scaffold(body: Text('Ready'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(repository.calls, ['Chase', 'Amex']);
    expect(find.text('Try again'), findsOneWidget);
    tester.widget<OnboardingAnimation>(find.byType(OnboardingAnimation)).onComplete!();
    expect(find.text('Ready'), findsNothing);
    repository.failAmex = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repository.calls, ['Chase', 'Amex', 'Amex']);
    expect(find.text('Ready'), findsOneWidget);
  });
}
