import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:spending_tracker/main.dart';
import 'package:spending_tracker/app_router.dart';
import 'package:spending_tracker/design_system/tokens.dart';
import 'package:spending_tracker/design_system/components.dart';
import 'package:spending_tracker/home/home_preview_data.dart';
import 'package:spending_tracker/auth/member_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/', extra: const GuestHomeAccess());
  });

  // 헤더 금액은 지출, 순금액, 수입 순으로 전환되고 필터 범위를 유지한다.
  testWidgets('홈 헤더 금액 전환과 결제수단별 수입', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    final amount = find.byKey(const Key('home-total-amount'));
    expect(find.text('\$812.45'), findsOneWidget);
    await tester.tap(amount);
    await tester.pump();
    expect(find.text('Total Spending + Income'), findsOneWidget);
    expect(find.text('-\$45.00'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, Colors.black);
    await tester.tap(amount);
    await tester.pump();
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('\$767.45'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, AppPalette.lime600);
    await tester.tap(amount);
    await tester.pump();
    expect(find.text('\$812.45'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-filter-option-1')));
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.text('\$482.30'), findsOneWidget);
    await tester.tap(amount);
    await tester.pump();
    expect(find.text('-\$482.30'), findsOneWidget);
    await tester.tap(amount);
    await tester.pump();
    expect(find.descendant(of: amount, matching: find.text('\$0.00')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 첫 진입 안내는 추가 버튼 위에 3초간 보이고 재진입 시 다시 나타나지 않는다.
  testWidgets('홈 첫 진입 추가 버튼 안내', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();

    final tooltip = find.byKey(const Key('home-add-tooltip'));
    expect(tooltip, findsOneWidget);
    expect(find.text("Enter today's spending"), findsOneWidget);
    expect(
      tester.getSize(
        find.descendant(of: tooltip, matching: find.byType(SvgPicture)),
      ),
      const Size(22, 15),
    );
    expect(
      tester.getBottomRight(tooltip).dy,
      lessThan(tester.getBottomRight(find.byType(AppBottomNavigation)).dy),
    );
    await tester.pump(const Duration(milliseconds: 2999));
    expect(tooltip, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tooltip, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pump();
    expect(tooltip, findsNothing);
  });

  // 18 Pro 크기에서 Figma의 18px 간격과 기본 요약 카드 노출을 확인한다.
  testWidgets('홈 기본 화면의 간격과 요약 카드 표시', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    final filterBottom = tester
        .getBottomRight(find.byKey(const Key('home-card-filter')))
        .dy;
    final sheetTop = tester
        .getTopLeft(find.byKey(const Key('home-calendar-sheet')))
        .dy;
    final cardBottom = tester
        .getBottomRight(find.byKey(const Key('home-day-summary')))
        .dy;
    final navTop = tester.getTopLeft(find.byType(AppBottomNavigation)).dy;
    expect(sheetTop - filterBottom, 18);
    expect(cardBottom, lessThanOrEqualTo(navTop));
    expect(tester.takeException(), isNull);
    final summary = find.byKey(const Key('home-day-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('Today · Aug 24')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('\$86.20')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('Chase')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('Amex')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('+1')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-day-edit-icon'))),
      const Size(28, 28),
    );
    expect(
      tester.widget<Container>(summary).padding,
      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    );

    final dayFour = find.byKey(const Key('home-day-4'));
    final firstDot = find.byKey(const Key('home-day-4-dot-0'));
    final secondDot = find.byKey(const Key('home-day-4-dot-1'));
    expect(
      tester.widget<Container>(dayFour).padding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: dayFour, matching: find.text('4')))
          .style!
          .fontWeight,
      FontWeight.w400,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: dayFour, matching: find.text('\$71')),
          )
          .style!
          .fontSize,
      12,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: dayFour, matching: find.text('\$71')),
          )
          .style!
          .fontWeight,
      FontWeight.w400,
    );
    expect(tester.getSize(firstDot), const Size(6, 6));
    expect(tester.getSize(secondDot), const Size(6, 6));
    expect(
      (tester.widget<Container>(firstDot).decoration as BoxDecoration).color,
      AppPalette.accentBlue,
    );
    expect(
      (tester.widget<Container>(secondDot).decoration as BoxDecoration).color,
      AppPalette.accentSky,
    );
    expect(tester.getTopLeft(secondDot).dx - tester.getTopLeft(firstDot).dx, 9);

    final firstClosing = find.byKey(const Key('home-closing-marker-0'));
    final secondClosing = find.byKey(const Key('home-closing-marker-1'));
    final todayMarker = find.byKey(const Key('home-today-marker'));
    expect(
      tester.getTopLeft(find.text('Chase').first).dy,
      tester.getTopLeft(find.text('Payday')).dy,
    );
    expect(
      tester.getTopLeft(firstClosing).dy,
      greaterThan(tester.getTopLeft(find.text('Payday')).dy),
    );
    expect(tester.getSize(firstClosing), const Size(10, 10));
    expect(tester.getSize(secondClosing), const Size(10, 10));
    expect(
      tester.getTopLeft(secondClosing).dx - tester.getTopLeft(firstClosing).dx,
      12,
    );
    expect(
      tester.getTopLeft(todayMarker).dy,
      tester.getTopLeft(firstClosing).dy,
    );
    expect(
      ((tester.widget<Container>(firstClosing).decoration as BoxDecoration)
                  .border
              as Border)
          .top
          .color,
      AppPalette.accentBlue,
    );
    expect(
      ((tester.widget<Container>(secondClosing).decoration as BoxDecoration)
                  .border
              as Border)
          .top
          .color,
      AppPalette.accentSky,
    );

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    final expandedCardBottom = tester
        .getBottomRight(find.byKey(const Key('home-day-summary')))
        .dy;
    expect(find.text('Mon, Aug 10'), findsOneWidget);
    expect(expandedCardBottom, lessThanOrEqualTo(navTop));
    expect(tester.takeException(), isNull);
  });

  // 날짜 카드의 첫 전개는 가게·메모만, 가게 전개는 품목·카테고리까지 보여준다.
  testWidgets('홈 일별 거래 카드의 두 단계 전개', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today · Aug 24'));
    await tester.pumpAndSettle();
    final detail = find.byKey(const Key('home-day-summary'));
    expect(
      find.descendant(of: detail, matching: find.text('Mon, Aug 24')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('Target')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('Sweetgreen')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('Shell')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detail,
        matching: find.text(HomePreviewData.initialNote),
      ),
      findsOneWidget,
    );
    expect(find.text('Groceries'), findsNothing);
    final decoration =
        tester.widget<Container>(detail).decoration as BoxDecoration;
    expect(decoration.color, AppTokens.background);
    expect((decoration.border as Border).top.color, AppTokens.borderSubtle);
    expect(
      tester.widget<Container>(detail).padding,
      const EdgeInsets.fromLTRB(20, 18, 20, 12),
    );
    expect(tester.widget<Container>(detail).clipBehavior, Clip.antiAlias);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('home-day-detail-count')))
          .style!
          .fontWeight,
      FontWeight.w400,
    );
    expect(
      tester.widget<Text>(find.text('Chase · 4 items')).style!.fontWeight,
      FontWeight.w400,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-day-detail-chevron'))),
      const Size(26, 26),
    );
    final dayChevron = find.descendant(
      of: find.byKey(const Key('home-day-detail-chevron')),
      matching: find.byType(SvgPicture),
    );
    expect(tester.getSize(dayChevron).width, closeTo(15.1667, 0.01));
    expect(tester.getSize(dayChevron).height, closeTo(8.66667, 0.01));
    expect(
      tester.getTopLeft(find.byKey(const Key('home-day-method-bar'))).dy -
          tester
              .getBottomRight(find.byKey(const Key('home-day-detail-toggle')))
              .dy,
      10,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('home-merchant-0-Target'))).dy -
          tester
              .getBottomRight(
                find.byKey(const Key('home-day-divider-0-Target')),
              )
              .dy,
      10,
    );
    expect(
      tester
              .getTopLeft(find.byKey(const Key('home-merchant-note-0-Target')))
              .dy -
          tester
              .getBottomRight(find.byKey(const Key('home-merchant-0-Target')))
              .dy,
      12,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-day-method-bar'))).height,
      8,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-merchant-icon-0-Target'))),
      const Size(34, 34),
    );

    await tester.ensureVisible(find.byKey(const Key('home-merchant-0-Target')));
    await tester.tap(find.byKey(const Key('home-merchant-0-Target')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Home supplies'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Home supplies')).overflow, isNull);
    final detailRight = tester.getBottomRight(detail).dx;
    expect(
      detailRight -
          tester
              .getBottomRight(
                find.byKey(const Key('home-item-amount-Groceries')),
              )
              .dx,
      21,
    );
    expect(
      tester
          .getBottomRight(find.byKey(const Key('home-item-amount-Groceries')))
          .dx,
      tester
          .getBottomRight(
            find.byKey(const Key('home-item-amount-Home supplies')),
          )
          .dx,
    );
    expect(find.text('Food'), findsWidgets);
    expect(find.byType(AppCategoryIcon), findsWidgets);
    expect(
      tester.getSize(find.byType(AppCategoryIcon).first),
      const Size(13, 13),
    );
    expect(find.text('Harvest bowl'), findsNothing);
    expect(find.byKey(const Key('home-day-expand-all')), findsNothing);
    expect(find.text('Expand All'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // 같은 날짜에 이름이 같은 예시 거래가 여러 개 있어도 상세 카드를 표시한다.
  testWidgets('동일한 거래명으로 일별 거래 카드 전개', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-day-4')));
    await tester.pumpAndSettle();

    expect(find.text('Tue, Aug 4'), findsOneWidget);
    expect(find.text('Expense'), findsNWidgets(2));
    expect(find.byKey(const Key('home-day-divider-0-Expense')), findsOneWidget);
    expect(find.byKey(const Key('home-day-divider-1-Expense')), findsOneWidget);
    final first = find.byKey(const Key('home-merchant-group-0'));
    final second = find.byKey(const Key('home-merchant-group-1'));
    final item = find.byKey(const Key('home-item-Expense'));
    await tester.ensureVisible(
      find.byKey(const Key('home-merchant-0-Expense')),
    );
    await tester.tap(find.byKey(const Key('home-merchant-0-Expense')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: first, matching: item), findsOneWidget);
    expect(find.descendant(of: second, matching: item), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('home-merchant-chevron-0'))),
      const Size(12, 7),
    );
    expect(find.byKey(const Key('home-day-collapse-all')), findsOneWidget);
    final addNote = tester.widget<Text>(find.text('+ Add note'));
    expect(addNote.style!.fontSize, 14);
    expect(addNote.style!.fontWeight, FontWeight.w600);
    expect(addNote.style!.color, AppPalette.purple500);

    await tester.drag(
      find.byKey(const Key('home-calendar-sheet')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-merchant-1-Expense')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: first, matching: item), findsOneWidget);
    expect(find.descendant(of: second, matching: item), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-merchant-0-Expense')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: first, matching: item), findsNothing);
    expect(find.descendant(of: second, matching: item), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('home-calendar-sheet')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-day-collapse-all')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: first, matching: item), findsNothing);
    expect(find.descendant(of: second, matching: item), findsNothing);
    expect(find.byKey(const Key('home-day-collapse-all')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // 폭이 작은 기기에서도 품목과 카테고리 배지가 가로로 넘치지 않는다.
  testWidgets('작은 화면의 일별 품목 전개', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('home-calendar-sheet')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-day-summary')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('home-merchant-0-Target')));
    await tester.tap(find.byKey(const Key('home-merchant-0-Target')));
    await tester.pumpAndSettle();
    expect(find.text('Home supplies'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Home supplies')).overflow, isNull);
    final detail = find.byKey(const Key('home-day-summary'));
    expect(
      tester.getBottomRight(detail).dx -
          tester
              .getBottomRight(
                find.byKey(const Key('home-item-amount-Home supplies')),
              )
              .dx,
      21,
    );
    expect(tester.takeException(), isNull);
  });

  // 작은 화면에서도 홈 달력이 넘치지 않고 카드 색이 선택에 따라 바뀌는지 확인한다.
  testWidgets('홈 화면과 카드별 헤더 표시', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Spent this month'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chase Sapphire'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.text('Chase'), findsWidgets);
    expect(find.text('\$482.30'), findsOneWidget);
    final legendMethods = find.byKey(const Key('home-legend-methods'));
    expect(
      find.descendant(of: legendMethods, matching: find.text('Chase')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: legendMethods, matching: find.text('Amex')),
      findsNothing,
    );
    expect(
      find.descendant(of: legendMethods, matching: find.text('Payday')),
      findsOneWidget,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppPalette.accentBlue,
    );
    expect(find.byKey(const Key('home-closing-marker-1')), findsNothing);
    expect(
      ((tester
                          .widget<Container>(
                            find.byKey(const Key('home-closing-marker-0')),
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border)
          .top
          .color,
      AppPalette.accentBlue,
    );
    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amex Gold'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-closing-marker-1')), findsNothing);
    expect(
      find.descendant(of: legendMethods, matching: find.text('Amex')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: legendMethods, matching: find.text('Chase')),
      findsNothing,
    );
    expect(
      ((tester
                          .widget<Container>(
                            find.byKey(const Key('home-closing-marker-0')),
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border)
          .top
          .color,
      AppPalette.accentSky,
    );
    expect(tester.takeException(), isNull);
  });

  // 결제수단을 바꾸면 날짜 거래 상자의 금액·건수·가게도 같은 범위로 바뀐다.
  testWidgets('홈 거래 상자가 선택한 결제수단만 표시', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chase Sapphire'));
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    final summary = find.byKey(const Key('home-day-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('\$22.13')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('Amex')),
      findsNothing,
    );

    await tester.ensureVisible(summary);
    await tester.tap(find.text('Today · Aug 24'));
    await tester.pumpAndSettle();
    expect(find.text('1 payment method · 4 items'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Sweetgreen'), findsNothing);

    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amex Gold'));
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.text('1 payment method · 5 items'), findsOneWidget);
    expect(find.text('Sweetgreen'), findsOneWidget);
    expect(find.text('Target'), findsNothing);

    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-filter-option-3')));
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.text('0 payment methods · 0 items'), findsOneWidget);
    expect(find.text('Sweetgreen'), findsNothing);
    final legendMethods = find.byKey(const Key('home-legend-methods'));
    expect(
      find.descendant(of: legendMethods, matching: find.text('Cash')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: legendMethods, matching: find.text('Chase')),
      findsNothing,
    );
    expect(
      find.descendant(of: legendMethods, matching: find.text('Payday')),
      findsOneWidget,
    );
    expect(find.text('Closing day'), findsNothing);

    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BofA Debit'));
    await tester.ensureVisible(find.byKey(const Key('home-filter-show')));
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.text('1 payment method · 4 items'), findsOneWidget);
    expect(find.text('Shell'), findsOneWidget);
    expect(find.text('Target'), findsNothing);
    expect(
      find.descendant(of: legendMethods, matching: find.text('Debit')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: legendMethods, matching: find.text('Cash')),
      findsNothing,
    );
    expect(find.text('Closing day'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // All 필터 시트는 선택 행과 헤더 버튼을 강조하고 Show 전에는 홈 선택을 바꾸지 않는다.
  testWidgets('홈 All 필터 시트 강조와 선택 유지', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.tap(find.byKey(const Key('home-card-filter')));
    await tester.pumpAndSettle();

    final highlight = find.byKey(const Key('home-filter-highlight'));
    final allOption = find.byKey(const Key('home-filter-option-0'));
    expect(find.byKey(const Key('home-filter-sheet')), findsOneWidget);
    expect(
      tester.getTopLeft(highlight),
      tester.getTopLeft(find.byKey(const Key('home-card-filter'))),
    );
    expect(tester.widget<Material>(highlight).color, AppTokens.brandLime);
    expect(tester.widget<Material>(allOption).color, AppTokens.surface);
    expect(find.text('Show spending for'), findsOneWidget);
    expect(
      find.text(
        'Cards follow their own cycle ·\nAll and cash use the calendar month',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('home-filter-sheet'))).dy,
      greaterThan(tester.getBottomRight(highlight).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(allOption);
    await tester.tap(find.byKey(const Key('home-filter-show')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-filter-sheet')), findsNothing);
    expect(find.byKey(const Key('home-filter-highlight')), findsNothing);
    expect(find.text('All'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppPalette.purple500,
    );
    expect(tester.takeException(), isNull);
  });

  // 월 시트는 헤더 캡슐을 강조하고 Done 이후에만 미래 월을 적용한다.
  testWidgets('홈 월 선택 시트와 미래 월 이동', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.tap(find.byKey(const Key('home-month-switcher')));
    await tester.pumpAndSettle();

    final highlight = find.byKey(const Key('home-month-highlight'));
    final switcher = find.byKey(const Key('home-month-switcher'));
    final monthSheet = find.byKey(const Key('home-month-sheet'));
    expect(monthSheet, findsOneWidget);
    expect(tester.getSize(highlight), tester.getSize(switcher));
    expect(tester.getTopLeft(highlight), tester.getTopLeft(switcher));
    final highlightedText = find.descendant(
      of: highlight,
      matching: find.text('Aug 2026'),
    );
    final normalText = find.descendant(
      of: switcher,
      matching: find.text('Aug 2026'),
    );
    expect(tester.getTopLeft(highlightedText), tester.getTopLeft(normalText));
    expect(
      tester.widget<Text>(highlightedText).style!.fontSize,
      tester.widget<Text>(normalText).style!.fontSize,
    );
    expect(
      tester.widget<Container>(highlight).decoration,
      isA<BoxDecoration>().having(
        (value) => value.color,
        'color',
        AppTokens.background,
      ),
    );
    expect(
      tester.getTopLeft(monthSheet).dy,
      greaterThan(tester.getBottomRight(highlight).dy),
    );
    expect(
      tester.widget<Material>(find.byKey(const Key('home-month-8'))).color,
      AppTokens.brandPurple,
    );

    await tester.tap(find.byKey(const Key('home-month-9')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Material>(find.byKey(const Key('home-month-9'))).color,
      AppTokens.brandPurple,
    );
    await tester.tap(find.byKey(const Key('home-month-done')));
    await tester.pumpAndSettle();
    expect(find.text('Sep 2026'), findsOneWidget);
    expect(highlight, findsNothing);

    await tester.tap(find.byKey(const Key('home-month-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-year-next')));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-month-12')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-month-done')));
    await tester.pumpAndSettle();
    expect(find.text('Dec 2027'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 작은 기기에서는 월 그리드를 스크롤해 Done까지 접근할 수 있다.
  testWidgets('작은 화면의 월 선택 시트', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.tap(find.byKey(const Key('home-month-switcher')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-month-sheet')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('home-month-done')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Simple 전환 시 특수 날짜 금액과 마감일 범례만 남고 거래 카드가 한 줄로 바뀐다.
  testWidgets('홈 Simple과 Detail 전환', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();

    final control = find.byType(AppSegmentedControl);
    final border =
        (tester
                        .widget<Container>(
                          find
                              .descendant(
                                of: control,
                                matching: find.byType(Container),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .border
            as Border;
    expect(border.top.width, 1.2);
    expect(border.top.color, AppTokens.background.withValues(alpha: 0.55));

    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();
    final dayFour = find.byKey(const Key('home-day-4'));
    expect(
      find.descendant(of: dayFour, matching: find.text('\$71')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-day-5')),
        matching: find.text('\$412'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-day-15')),
        matching: find.text('\$356'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: dayFour, matching: find.text('4')))
          .style!
          .fontSize,
      14,
    );
    expect(
      find.text('Closing date (cycle total, in card color)'),
      findsOneWidget,
    );
    expect(find.text('Payday'), findsNothing);
    final summary = find.byKey(const Key('home-day-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('Chase')),
      findsNothing,
    );
    expect(
      find.descendant(of: summary, matching: find.text('\$86.20')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('home-day-edit-icon'))),
      const Size(30, 30),
    );
    expect(
      tester.getBottomRight(summary).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBottomNavigation)).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Detail'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: dayFour, matching: find.text('\$71')),
      findsOneWidget,
    );
    expect(find.text('Payday'), findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text('Chase')),
      findsOneWidget,
    );
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    expect(find.text('1 payment method · 1 item'), findsOneWidget);
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();
    expect(find.text('1 payment method · 1 item'), findsNothing);
    expect(
      find.descendant(of: summary, matching: find.text('Chase')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  // 좁은 화면에서도 Simple 범례와 한 줄 요약 카드가 가로로 넘치지 않는다.
  testWidgets('작은 화면의 홈 Simple 표시', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();

    expect(
      find.text('Closing date (cycle total, in card color)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-day-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 연필 아이콘은 거래 카드를 펼치지 않고 메모 시트를 열며 저장·취소를 구분한다.
  testWidgets('홈 날짜 메모 열기와 저장', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();
    final editIcon = find.byKey(const Key('home-day-edit-icon'));
    expect(
      (tester.widget<Container>(editIcon).decoration as BoxDecoration).color,
      AppTokens.brandLime,
    );

    await tester.tap(editIcon);
    await tester.pumpAndSettle();
    expect(find.text('Tue, Aug 24'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Costco run for the party this weekend'), findsOneWidget);
    expect(find.text('37 / 200'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('4 payment methods · 13 items'), findsNothing);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppTokens.brandPurple,
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('home-note-sheet'))).dy,
      574,
    );
    await tester.enterText(
      find.byKey(const Key('home-note-input')),
      'New note',
    );
    await tester.pump();
    expect(find.text('8 / 200'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.tap(editIcon);
    await tester.pumpAndSettle();
    expect(find.text('Costco run for the party this weekend'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('home-note-input')),
      'Saved note',
    );
    await tester.tap(find.byKey(const Key('home-note-save')));
    await tester.pumpAndSettle();
    await tester.tap(editIcon);
    await tester.pumpAndSettle();
    expect(find.text('Saved note'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home-note-input')), '');
    await tester.tap(find.byKey(const Key('home-note-save')));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Container>(editIcon).decoration as BoxDecoration).color,
      AppTokens.surface,
    );
    expect(tester.takeException(), isNull);
  });

  // 검색 중에도 달력이 남고 취소하면 월 선택 헤더가 복원되는지 확인한다.
  testWidgets('홈 검색을 열고 취소한다', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const SpendingTrackerApp());
    await tester.pumpAndSettle();
    final calendarTop = tester.getTopLeft(find.byType(AppMonthCalendar)).dy;
    final calendarBottom = tester
        .getBottomRight(find.byKey(const Key('home-calendar-sheet')))
        .dy;
    final navigationTop = tester
        .getTopLeft(find.byType(AppBottomNavigation))
        .dy;
    final controlTop = tester
        .getTopLeft(find.byKey(const Key('home-month-switcher')))
        .dy;
    await tester.tap(find.byKey(const Key('home-search-button')));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
    expect(find.byKey(const Key('home-day-summary')), findsOneWidget);
    expect(find.text('Aug 2026'), findsNothing);
    expect(tester.getTopLeft(find.byType(AppMonthCalendar)).dy, calendarTop);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-search-field'))).dy,
      controlTop,
    );

    await tester.enterText(find.byType(TextField), 'latte');
    await tester.pumpAndSettle();
    expect(find.text('5 days with “latte” this month'), findsOneWidget);
    expect(find.byKey(const Key('home-day-summary')), findsNothing);
    expect(find.text('\$24.16'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AppMonthCalendar)).dy, calendarTop);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-day-summary')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'latte');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spent this month'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final keyboardBackdrop = find.byKey(
      const Key('home-search-keyboard-backdrop'),
    );
    expect(tester.getSize(keyboardBackdrop).height, 300);
    expect(
      tester.widget<ColoredBox>(keyboardBackdrop).color,
      AppTokens.background,
    );
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(AppBottomNavigation)).dy,
      navigationTop,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppTokens.brandPurple,
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('home-calendar-sheet'))).dy,
      calendarBottom,
    );
    expect(tester.getTopLeft(find.byType(AppMonthCalendar)).dy, calendarTop);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-search-field'))).dy,
      controlTop,
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(keyboardBackdrop, findsNothing);
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(AppBottomNavigation)).dy,
      navigationTop,
    );

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Aug 2026'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
