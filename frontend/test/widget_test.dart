import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/main.dart';

void main() {
  // Flutter 앱이 기본 홈 화면을 표시하는지 확인한다.
  testWidgets('앱 기본 화면 표시', (tester) async {
    await tester.pumpWidget(const SpendingTrackerApp());

    expect(find.text('Spending Tracker'), findsOneWidget);
  });
}
