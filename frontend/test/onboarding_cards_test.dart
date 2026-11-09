import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/onboarding/onboarding_cards_page.dart';
import 'package:spending_tracker/onboarding/onboarding_closing_page.dart';
import 'package:spending_tracker/onboarding/onboarding_setup_intro_page.dart';

void main() {
  testWidgets('카드 선택 순서와 최대 두 개 제한', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(
          path: '/setup',
          name: 'onboarding-setup',
          builder: (_, _) => const OnboardingSetupIntroPage(),
        ),
        GoRoute(
          path: '/cards',
          name: 'onboarding-cards',
          builder: (_, _) => const OnboardingCardsPage(),
        ),
        GoRoute(path: '/closing', name: 'onboarding-closing', builder: (_, state) => OnboardingClosingPage(cards: state.extra as List<String>)),
        GoRoute(path: '/', name: 'home', builder: (_, _) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingCardsPage), findsOneWidget);
    expect(find.text('Continue · 0 cards'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('onboarding-cards-continue')))
          .onPressed,
      isNull,
    );
    bool selected(String label) =>
        tester.widget<AppOption>(find.byKey(ValueKey(label))).selected;
    expect(selected('Chase'), isFalse);
    await tester.tap(find.text('Chase'));
    await tester.pump();
    expect(find.text('Continue · 1 card'), findsOneWidget);
    await tester.tap(find.text('Amex'));
    await tester.pump();
    expect(find.text('Continue · 2 cards'), findsOneWidget);
    await tester.tap(find.text('Citi'));
    await tester.pump();
    expect(selected('Chase'), isFalse);
    expect(selected('Amex'), isTrue);
    expect(selected('Citi'), isTrue);
    await tester.tap(find.text('Amex'));
    await tester.pump();
    expect(selected('Amex'), isFalse);
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboarding-custom-card-name')), 'Navy Federal');
    await tester.pump();
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    expect(selected('Navy Federal'), isTrue);
    await tester.tap(find.text('Continue · 2 cards'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingClosingPage), findsOneWidget);
    expect(find.text('Citi'), findsOneWidget);
    expect(find.text('Navy Federal'), findsOneWidget);
  });

  testWidgets('진행률은 처음에 0에서 2/5까지 채워진다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingCardsPage()));
    double progress() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(progress(), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), greaterThan(0));
    expect(progress(), lessThan(0.4));
    await tester.pump(const Duration(milliseconds: 150));
    expect(progress(), closeTo(0.4, 0.001));
  });

  testWidgets('작은 화면에서 카드 선택 화면을 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: OnboardingCardsPage()));
    await tester.ensureVisible(find.text('Other'));
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('onboarding-custom-card-name')), 'Navy');
    await tester.pump();
    await tester.ensureVisible(find.text('Add card'));
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    expect(find.text('Continue · 1 card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('직접 입력은 문자와 공백만 허용하고 중복을 선택한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingCardsPage()));
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('onboarding-custom-card-name'));
    expect(tester.widget<AppButton>(find.widgetWithText(AppButton, 'Add card')).onPressed, isNull);
    await tester.enterText(input, '한글 123! École');
    await tester.pump();
    expect(tester.widget<TextField>(find.descendant(of: input, matching: find.byType(TextField))).controller!.text, '한글  École');
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppOption>(find.byKey(const ValueKey('한글  École'))).selected, isTrue);
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.enterText(input, 'chase');
    await tester.pump();
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppOption>(find.byKey(const ValueKey('Chase'))).selected, isTrue);
    expect(find.text('chase'), findsNothing);
    expect(find.text('Continue · 2 cards'), findsOneWidget);
  });
}
