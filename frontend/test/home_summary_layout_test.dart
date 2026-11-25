import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/home/home_transaction_data.dart';
import 'package:spending_tracker/home/widgets/home_transaction_section.dart';

void main() {
  for (final date in [DateTime(2027, 8, 1), DateTime(2026, 8, 24)]) {
    testWidgets('좁은 화면의 거래 요약은 같은 행에 메모 아이콘을 표시한다: $date', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeTransactionSection(
        selectedDate: date, transactions: previewHomeTransactions(date, 0), isToday: date == DateTime(2026, 8, 24), view: 1, expanded: false,
        expandedTransactions: const {}, merchantNotes: const {},
        onExpand: () {}, onCollapse: () {}, onCollapseAll: () {},
        onToggleTransaction: (_) {}, onOpenNoteEditor: (_) {},
      ))));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.byKey(const Key('home-day-summary')));
      expect(box.width, lessThanOrEqualTo(320));
      expect(find.byKey(const Key('home-day-edit-icon')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
