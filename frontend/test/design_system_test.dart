import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/design_system/tokens.dart';
import 'package:spending_tracker/design_system/typography.dart';

void main() {
  // 최신 Figma 색상과 숫자·캡션 스타일이 공통 토큰에 반영됐는지 확인한다.
  test('디자인 토큰과 타이포그래피가 최신 Figma 값과 맞는다', () {
    expect(AppPalette.accentYellow, const Color(0xFFF2D857));
    expect(AppPalette.accentGreen, const Color(0xFF51E075));
    expect(AppPalette.accentTeal, const Color(0xFF51E0CD));
    expect(AppPalette.accentMagenta, const Color(0xFFCF5BFC));
    expect(AppTokens.overlayDim, const Color(0x73141F18));
    expect(AppTokens.textInverse, AppPalette.neutral0);
    expect(AppTypography.displayLarge.fontSize, 40);
    expect(AppTypography.displayLarge.letterSpacing, -0.4);
    expect(AppTypography.displayNumber.fontSize, 32);
    expect(AppTypography.displayNumber.letterSpacing, -0.32);
    expect(AppTypography.displayAmount.fontSize, 56);
    expect(AppTypography.displayAmount.fontWeight, FontWeight.w500);
    expect(AppTypography.displayAmount.letterSpacing, -1.12);
    expect(AppTypography.caption.fontWeight, FontWeight.w400);
  });

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

    expect(
      tester.getSize(
        find
            .descendant(
              of: find.byType(AppNotification),
              matching: find.byType(SvgPicture),
            )
            .first,
      ),
      const Size(22, 22),
    );
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

  // 입력창이 포커스되면 흰 배경과 Figma 코드의 1.5px 보라색 테두리로 바뀐다.
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
      AppTokens.surface,
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.fillColor, AppTokens.background);
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.width,
      1.5,
    );
  });

  // 버튼 변형은 상태별 색과 소셜 로고를 같은 56px 캡슐 안에 표시한다.
  testWidgets('버튼 변형과 소셜 로고 슬롯이 Figma 색을 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppButton(
                key: const Key('secondary'),
                label: 'Secondary',
                onPressed: () {},
                variant: AppButtonVariant.secondary,
              ),
              AppButton(
                key: const Key('danger'),
                label: 'Danger',
                onPressed: () {},
                variant: AppButtonVariant.danger,
              ),
              AppButton(
                key: const Key('social-google'),
                label: 'Google',
                onPressed: () {},
                variant: AppButtonVariant.social,
                socialLogo: AppSocialLogo.google,
              ),
              AppButton(
                key: const Key('social-apple'),
                label: 'Apple',
                onPressed: () {},
                variant: AppButtonVariant.social,
                socialLogo: AppSocialLogo.apple,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final secondary = find.descendant(
      of: find.byKey(const Key('secondary')),
      matching: find.byType(Material),
    );
    final danger = find.descendant(
      of: find.byKey(const Key('danger')),
      matching: find.byType(Material),
    );
    final social = find.descendant(
      of: find.byKey(const Key('social-google')),
      matching: find.byType(Material),
    );
    expect(tester.widget<Material>(secondary).color, AppTokens.brandPurple);
    expect(tester.widget<Material>(danger).color, AppTokens.statusDanger);
    expect(tester.widget<Material>(social).color, AppTokens.surface);
    expect(
      (tester.widget<Material>(secondary).shape as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.circular(28),
    );
    expect(
      tester.widget<Text>(find.text('Secondary')).style!.color,
      AppTokens.textInverse,
    );
    expect(
      tester.widget<Text>(find.text('Danger')).style!.color,
      AppTokens.textInverse,
    );
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const Key('social-google')),
          matching: find.byType(SvgPicture),
        ),
      ),
      const Size(20, 20),
    );
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const Key('social-apple')),
          matching: find.byType(SvgPicture),
        ),
      ),
      const Size(20, 20),
    );
    expect(tester.takeException(), isNull);
  });

  // 공통 상태 위젯의 표면색과 활성 테두리는 화면별 하드코딩 없이 일치해야 한다.
  testWidgets('입력 숫자·옵션·정보 카드의 상태별 표면이 Figma와 맞는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const AppCodeDigit(key: Key('digit-empty')),
                const AppCodeDigit(
                  key: Key('digit-active'),
                  state: AppCodeDigitState.active,
                ),
                AppOption(
                  key: const Key('option-default'),
                  label: 'Credit card',
                  selected: false,
                  onTap: () {},
                ),
                const AppInfoCard(
                  key: Key('info-neutral'),
                  title: 'Cycle',
                  body: '12 days',
                ),
                const AppInfoCard(
                  key: Key('info-brand'),
                  title: 'Cycle',
                  body: '12 days',
                  tone: AppInfoCardTone.brand,
                ),
                const AppInfoCard(
                  key: Key('info-warning'),
                  title: 'Cycle',
                  body: '12 days',
                  tone: AppInfoCardTone.warning,
                ),
                const AppCardBadge(letter: 'C', size: AppCardBadgeSize.medium),
                const AppChip(
                  key: Key('chip-expense'),
                  label: 'Expense',
                  tone: AppChipTone.expense,
                ),
                const AppProgress(key: Key('progress'), step: 1),
                const AppNotification(
                  key: Key('notification'),
                  title: 'Closing soon',
                  body: 'Cycle total',
                  meta: '9:00 AM',
                  type: AppNotificationType.cardClosing,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final empty =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(const Key('digit-empty')),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration;
    final active =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byKey(const Key('digit-active')),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(empty.color, AppTokens.surface);
    expect(active.color, AppTokens.background);
    expect((active.border as Border).top.width, 1.5);
    expect((active.border as Border).top.color, AppTokens.brandPurple);
    expect(
      tester
          .widget<Material>(
            find.descendant(
              of: find.byKey(const Key('option-default')),
              matching: find.byType(Material),
            ),
          )
          .color,
      AppTokens.background,
    );
    expect(tester.widget<Text>(find.text('Credit card')).style!.fontSize, 14);
    expect(
      (tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('info-neutral')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      AppTokens.surface,
    );
    expect(
      (tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('info-brand')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      AppTokens.surface,
    );
    expect(
      (tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(const Key('info-warning')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      AppComponentColors.warningSubtle,
    );
    expect(tester.widget<Text>(find.text('C')).style!.height, 1.5);
    expect(
      tester
          .widget<Material>(
            find.descendant(
              of: find.byKey(const Key('chip-expense')),
              matching: find.byType(Material),
            ),
          )
          .color,
      AppTokens.brandPurple,
    );
    expect(
      tester.widget<Text>(find.text('Expense')).style!.color,
      AppTokens.textInverse,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .backgroundColor,
      AppTokens.surface,
    );
    final icon = find
        .descendant(
          of: find.byKey(const Key('notification')),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getSize(icon), const Size(44, 44));
    expect(
      tester.widget<Text>(find.text('Cycle total')).style!.color,
      AppTokens.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('9:00 AM')).style!.color,
      AppTokens.textDisabled,
    );
    expect(tester.takeException(), isNull);
  });
}
