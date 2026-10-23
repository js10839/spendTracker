import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/design_system/calendar.dart';

void main() {
  // 윤년의 날짜와 시작 요일을 확인해 달력 칸이 한 칸씩 밀리지 않게 한다.
  testWidgets('윤년 2월의 날짜와 요일 배치가 맞다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppMonthCalendar(month: DateTime(2024, 2)),
          ),
        ),
      ),
    );

    expect(find.text('29'), findsOneWidget);
    expect(find.text('30'), findsNothing);
    expect(
      tester.getCenter(find.text('1')).dx,
      closeTo(tester.getCenter(find.text('THU')).dx, 1),
    );
    expect(tester.takeException(), isNull);
  });

  // 화면별 칸 표현을 유지하면서 선택 가능 범위와 콜백을 공유하는지 확인한다.
  testWidgets('날짜 표현을 바꿔도 선택 범위가 적용된다', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppMonthCalendar(
            month: DateTime(2026, 8),
            selectedDate: DateTime(2026, 8, 15),
            firstDate: DateTime(2026, 8, 10),
            lastDate: DateTime(2026, 8, 24),
            onDateSelected: (date) => selected = date,
            dayBuilder: (context, date, enabled, isSelected) => Center(
              child: Text(
                '${date.day}:${enabled ? 'on' : 'off'}:${isSelected ? 'selected' : 'plain'}',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('15:on:selected'), findsOneWidget);
    await tester.tap(find.text('9:off:plain'));
    expect(selected, isNull);
    await tester.tap(find.text('24:on:plain'));
    expect(selected, DateTime(2026, 8, 24));
    expect(tester.takeException(), isNull);
  });
}
