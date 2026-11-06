import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/design_system/closing_day_picker.dart';
import 'package:spending_tracker/design_system/tokens.dart';
import 'package:spending_tracker/onboarding/closing_cycle.dart';
import 'package:spending_tracker/onboarding/onboarding_closing_page.dart';

void main() {
  testWidgets('날짜는 선택 해제 후 변경하고 말일 버튼은 바로 변경한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingClosingPage(cards: ['Chase'])));
    await tester.tap(find.byKey(const ValueKey('closing-day-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('closing-day-6')));
    await tester.pump();
    expect(find.textContaining('5th, every month'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('closing-day-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('closing-day-6')));
    await tester.pump();
    expect(find.textContaining('6th, every month'), findsOneWidget);
    await tester.ensureVisible(find.text('Last day of month'));
    await tester.tap(find.text('Last day of month'));
    await tester.pump();
    expect(find.byKey(const ValueKey('closing-day-31')), findsOneWidget);
    expect(tester.widget<AppClosingDayPicker>(find.byType(AppClosingDayPicker)).selectedDay, 31);
  });
  testWidgets('오늘 글자는 선택 상태에 맞게 표시된다', (tester) async {
    Future<void> showPicker(int? selected) => tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AppClosingDayPicker(selectedDay: selected, today: DateTime(2026, 8, 24), onSelected: (_) {})),
    ));
    Color? todayColor() => tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('closing-day-24')), matching: find.text('24'))).style?.color;
    await showPicker(null);
    expect(todayColor(), AppTokens.textAccent);
    await showPicker(5);
    expect(todayColor(), AppTokens.textAccent);
    await showPicker(24);
    expect(todayColor(), AppTokens.textInverse);
  });
  test('마감일은 짧은 달과 연도 경계에서 보정된다', () {
    expect(closingCycle(DateTime(2024, 2, 20), 31).end, DateTime(2024, 2, 29));
    final cycle = closingCycle(DateTime(2025, 12, 30), 5);
    expect(cycle.start, DateTime(2025, 12, 6));
    expect(cycle.end, DateTime(2026, 1, 5));
    expect(ordinalDay(11), '11th');
    expect(ordinalDay(21), '21st');
  });

  testWidgets('카드별 날짜를 유지하고 둘 다 설정해야 Continue가 나온다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingClosingPage(cards: ['Chase', 'Amex'])),
    );
    await tester.pumpAndSettle();
    final button = find.byType(AppButton);
    expect(tester.widget<AppButton>(button).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('closing-day-5')));
    await tester.pump();
    expect(find.text('Next: Amex closing date'), findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('When does your Amex statement close?'), findsOneWidget);
    expect(tester.widget<AppButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('closing-day-10')));
    await tester.tap(find.byKey(const ValueKey('closing-day-10')));
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('closing-card-Chase')),
    );
    await tester.tap(find.byKey(const ValueKey('closing-card-Chase')));
    await tester.pump();
    expect(find.textContaining('5th, every month'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text("I'm not sure, set it later"), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('closing-card-Amex')));
    await tester.tap(find.byKey(const ValueKey('closing-card-Amex')));
    await tester.pump();
    expect(find.text('When does your Amex statement close?'), findsOneWidget);
    expect(find.textContaining('10th, every month'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 말일을 선택할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingClosingPage(cards: ['Chase'])),
    );
    await tester.ensureVisible(find.text('Last day of month'));
    await tester.tap(find.text('Last day of month'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Last day of month'));
    await tester.pump();
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('closing-day-31')));
    await tester.tap(find.byKey(const ValueKey('closing-day-31')));
    await tester.pump();
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
