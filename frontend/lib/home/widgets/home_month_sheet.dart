import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 홈 달력에서 연도와 월을 골라 Done으로 확정하는 시트다.
class HomeMonthSheet extends StatefulWidget {
  const HomeMonthSheet({
    super.key,
    required this.initialMonth,
    required this.maxHeight,
  });

  final DateTime initialMonth;
  final double maxHeight;

  @override
  /// 현재 표시 월을 시트의 임시 선택값으로 사용한다.
  State<HomeMonthSheet> createState() => _HomeMonthSheetState();
}

class _HomeMonthSheetState extends State<HomeMonthSheet> {
  late DateTime _selected;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _previewTotals = <int, String>{
    6: '\$1,034',
    7: '\$1,187',
    8: '\$812',
  };

  @override
  /// 시트를 닫기 전까지 기존 달력 월은 유지한다.
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  @override
  /// 연도 이동과 3열 월 선택을 Figma 크기로 표시한다.
  Widget build(BuildContext context) => Material(
    key: const Key('home-month-sheet'),
    color: AppTokens.background,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTokens.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Select month',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading3,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Material(
                        color: AppTokens.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: const Key('home-this-month'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() {
                            final now = DateTime.now();
                            _selected = DateTime(now.year, now.month);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            child: Text(
                              'This month',
                              style: AppTypography.bodyMediumStrong.copyWith(
                                color: AppPalette.neutral600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _yearButton(-1, 'imgPrevYear.svg'),
                    const SizedBox(width: 22),
                    Text('${_selected.year}', style: AppTypography.heading3),
                    const SizedBox(width: 22),
                    _yearButton(1, 'imgNextYear.svg'),
                  ],
                ),
                const SizedBox(height: 18),
                Column(
                  children: [
                    for (var row = 0; row < 4; row++) ...[
                      if (row > 0) const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          for (var column = 0; column < 3; column++) ...[
                            if (column > 0)
                              const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _monthTile(row * 3 + column + 1)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Future months are available · amounts = monthly total',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Material(
                    color: AppTokens.brandPurple,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      key: const Key('home-month-done'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(_selected),
                      child: Center(
                        child: Text(
                          'Done',
                          style: AppTypography.heading3.copyWith(
                            color: AppTokens.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// 연도 화살표를 누르면 같은 월을 이전 또는 다음 연도에서 볼 수 있다.
  Widget _yearButton(int delta, String asset) => InkWell(
    key: Key('home-year-${delta < 0 ? 'previous' : 'next'}'),
    customBorder: const CircleBorder(),
    onTap: () => setState(() {
      _selected = DateTime(_selected.year + delta, _selected.month);
    }),
    child: SvgPicture.asset('assets/home/$asset', width: 30, height: 30),
  );

  /// 미래 월도 선택 가능하게 두고 예시 금액은 2026년의 해당 월에만 보여준다.
  Widget _monthTile(int month) {
    final selected = _selected.month == month;
    final previewTotal = _selected.year == 2026 ? _previewTotals[month] : null;
    return Material(
      key: Key('home-month-$month'),
      color: selected ? AppTokens.brandPurple : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => setState(() {
          _selected = DateTime(_selected.year, month);
        }),
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _months[month - 1],
                style: AppTypography.bodyMediumStrong.copyWith(
                  color: selected
                      ? AppTokens.background
                      : AppTokens.textPrimary,
                ),
              ),
              if (previewTotal != null) ...[
                const SizedBox(height: 3),
                Text(
                  previewTotal,
                  style: AppTypography.caption.copyWith(
                    color: selected
                        ? AppTokens.background
                        : AppTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
