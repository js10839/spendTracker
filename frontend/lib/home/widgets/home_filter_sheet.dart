import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 홈의 지출 범위를 고르고 Show를 누를 때 선택값을 반환한다.
class HomeFilterSheet extends StatefulWidget {
  const HomeFilterSheet({
    super.key,
    required this.initialSelection,
    required this.month,
    required this.maxHeight,
  });

  final int initialSelection;
  final DateTime month;
  final double maxHeight;

  @override
  /// 필터 선택을 Show 전까지 시트 안에서만 유지한다.
  State<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<HomeFilterSheet> {
  late int _selected;

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
  static const _titles = [
    'All',
    'Chase Sapphire',
    'Amex Gold',
    'Cash',
    'BofA Debit',
  ];
  static const _amounts = [
    '\$812.45',
    '\$482.30',
    '\$96.20',
    '\$64.50',
    '\$28.00',
  ];
  static const _badges = ['', 'C', 'A', 'Ca', 'B'];
  static const _badgeColors = [
    AppTokens.textPrimary,
    AppPalette.accentBlue,
    AppPalette.accentSky,
    AppPalette.accentOrange,
    AppPalette.accentPink,
  ];

  @override
  /// 현재 홈 필터를 처음 선택된 행으로 표시한다.
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  /// 카드별 청구 주기와 월 기준 범위를 Figma 행 스타일로 보여준다.
  Widget build(BuildContext context) {
    final monthName = _months[widget.month.month - 1];
    final nextMonthName = _months[widget.month.month % 12];
    final lastDay = DateUtils.getDaysInMonth(
      widget.month.year,
      widget.month.month,
    );
    final calendarRange = '$monthName 1 – $lastDay';
    final descriptions = [
      'Cards & cash combined ·\n$calendarRange',
      'Cycle $monthName 6 – $nextMonthName 5',
      'Cycle $monthName 16 – $nextMonthName 15',
      calendarRange,
      calendarRange,
    ];

    return Material(
      key: const Key('home-filter-sheet'),
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
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show spending for',
                            style: AppTypography.heading3,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cards follow their own cycle ·\nAll and cash use the calendar month',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (var index = 0; index < _titles.length; index++) ...[
                    if (index > 0) const SizedBox(height: 6),
                    _filterRow(index, descriptions[index]),
                  ],
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Material(
                      color: AppTokens.brandPurple,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: const Key('home-filter-show'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(_selected),
                        child: Center(
                          child: Text(
                            'Show',
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
  }

  /// 선택 행만 회색 바탕과 Figma의 라디오 SVG로 강조한다.
  Widget _filterRow(int index, String description) => Material(
    key: Key('home-filter-option-$index'),
    color: _selected == index ? AppTokens.surface : AppTokens.background,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => setState(() => _selected = index),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (index == 0)
              SvgPicture.asset(
                'assets/home/imgAllFilter.svg',
                width: 36,
                height: 36,
              )
            else
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _badgeColors[index],
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _badges[index],
                  style: AppTypography.bodyMediumStrong.copyWith(
                    color: index == 1
                        ? AppTokens.background
                        : AppTokens.textPrimary,
                    fontSize: index == 3 ? 12 : 14,
                  ),
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titles[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLargeStrong,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: AppTypography.caption.copyWith(
                      color: AppTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _amounts[index],
              style: AppTypography.bodyMediumStrong.copyWith(
                color: AppPalette.neutral600,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (_selected == index)
              SvgPicture.asset(
                'assets/home/imgSelectedFilterRadio.svg',
                width: 22,
                height: 22,
              )
            else
              const SizedBox(width: 22, height: 22),
          ],
        ),
      ),
    ),
  );
}
