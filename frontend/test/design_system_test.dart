import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/design_system/tokens.dart';

void main() {
  // 작은 화면에서도 실제 입력과 알림 문구가 넘치지 않는지 확인한다.
  testWidgets('공통 컴포넌트가 작은 화면과 긴 문구를 처리한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppInput(controller: controller, hintText: '이메일 주소'),
              const SizedBox(height: 12),
              AppNotification(
                title: '이번 명세서 마감일이 다가오고 있습니다',
                body: '카드 지출 금액을 확인해 주세요. 긴 알림 본문도 여러 줄로 표시됩니다.',
                meta: '오전 9:00',
                type: AppNotificationType.cardClosing,
                unread: true,
              ),
              const SizedBox(height: 12),
              AppButton(label: '계속하기', onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'name@example.com');
    expect(find.text('name@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(430, 932);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // 선택 위젯이 부모 화면의 상태를 실제로 변경하는지 확인한다.
  testWidgets('선택지와 보기 전환이 콜백을 전달한다', (tester) async {
    var selected = false;
    var mode = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppOption(
                label: '신용카드',
                selected: false,
                onTap: () => selected = true,
              ),
              AppSegmentedControl(
                selectedIndex: 0,
                onChanged: (value) => mode = value,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('신용카드'));
    await tester.tap(find.text('Detail'));
    expect(selected, isTrue);
    expect(mode, 1);
  });

  // Figma에서 받은 SVG가 실제 위젯 트리에서 로드되는지 확인한다.
  testWidgets('뒤로 가기와 알림 SVG가 렌더링된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppBackButton(onPressed: () {}),
              const AppNotification(
                title: '영수증',
                body: '처리 완료',
                meta: '오전 9:00',
                type: AppNotificationType.receiptScans,
                unread: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // 새 카드와 토스트가 작은 화면에 들어가고 토스트 동작이 전달되는지 확인한다.
  testWidgets('추가 컴포넌트가 작은 화면에서 동작한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var actionCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AppCardBadge(letter: 'C', size: AppCardBadgeSize.large),
              const SizedBox(height: 12),
              const AppInfoCard(
                title: '현재 사이클: 8/6 – 9/5',
                body: '마감까지 12일',
                tone: AppInfoCardTone.brand,
              ),
              const SizedBox(height: 12),
              AppToast(
                message: '저장했어요',
                actionLabel: '실행 취소',
                onAction: () => actionCalled = true,
              ),
              const SizedBox(height: 12),
              const AppNotification(
                title: '카드 마감',
                body: '3일 남음',
                meta: '오전 9:00',
                type: AppNotificationType.cardClosing,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('실행 취소'));
    expect(actionCalled, isTrue);
  });

  // 기본 입력창이 포커스되면 흰 배경과 2px 보라색 테두리로 바뀌는지 확인한다.
  testWidgets('입력 포커스 상태가 새 디자인 값을 적용한다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInput(controller: controller, hintText: '이메일 주소'),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
      AppComponentColors.surface,
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.fillColor, AppTokens.background);
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.width,
      2,
    );
  });
}
