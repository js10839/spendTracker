import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// 월별 마감일과 매월 말일을 선택한다. 31일은 짧은 달에 말일로 처리한다.
class AppClosingDayPicker extends StatelessWidget {
  const AppClosingDayPicker({
    super.key,
    required this.selectedDay,
    required this.onSelected,
    required this.today,
  });

  final int? selectedDay;
  final ValueChanged<int?> onSelected;
  final DateTime today;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppDaySelectionGrid(
        itemCount: 31,
        itemBuilder: (context, index) => _day(index + 1),
      ),
      const SizedBox(height: 10),
      const AppTodayLegend(),
      const SizedBox(height: 14),
      Material(
        color: AppTokens.background,
        shape: StadiumBorder(side: BorderSide(color: AppTokens.borderSubtle)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: () => onSelected(31),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'Last day of month',
              style: AppTypography.caption.copyWith(color: AppTokens.textBody),
            ),
          ),
        ),
      ),
    ],
  );

  /// 날짜를 선택하고 오늘은 보라색 테두리로 표시한다.
  Widget _day(int day) {
    final selected = selectedDay == day;
    return AppDaySelectionTile(
      key: ValueKey('closing-day-$day'),
      label: '$day',
      selected: selected,
      today: today.day == day,
      muted: selectedDay != null && !selected,
      onTap: selectedDay != null && !selected
          ? null
          : () => onSelected(selected ? null : day),
    );
  }
}

/// 날짜와 요일을 7열에 동일한 간격으로 배치한다.
class AppDaySelectionGrid extends StatelessWidget {
  const AppDaySelectionGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < (itemCount + 6) ~/ 7; row++) ...[
        if (row > 0) const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var column = 0; column < 7; column++) ...[
              if (column > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: row * 7 + column < itemCount
                    ? itemBuilder(context, row * 7 + column)
                    : const SizedBox(height: 49),
              ),
            ],
          ],
        ),
      ],
    ],
  );
}

/// 날짜와 요일 선택에서 동일한 크기와 오늘 표시를 사용한다.
class AppDaySelectionTile extends StatelessWidget {
  const AppDaySelectionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.today,
    required this.onTap,
    this.muted = false,
    this.centered = false,
  });

  final String label;
  final bool selected;
  final bool today;
  final bool muted;
  final bool centered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppTokens.brandPurple : AppTokens.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      onTap: onTap,
      child: Container(
        height: 49,
          padding: EdgeInsets.only(top: 6, bottom: centered ? 5 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: today
              ? Border.all(
                  color: AppTokens.brandPurple.withValues(alpha: 114 / 255),
                  width: 1.5,
                )
              : null,
        ),
        alignment: centered ? Alignment.center : Alignment.topCenter,
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: selected
                ? AppTokens.textInverse
                : today
                ? AppTokens.textAccent
                : muted
                ? AppTokens.textDisabled
                : AppTokens.textPrimary,
          ),
        ),
      ),
    ),
  );
}

/// 오늘 날짜 테두리의 의미를 설명한다.
class AppTodayLegend extends StatelessWidget {
  const AppTodayLegend({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTokens.brandPurple.withValues(alpha: 114 / 255),
            width: 1.5,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        'Today',
        style: AppTypography.caption.copyWith(color: AppTokens.textSecondary),
      ),
    ],
  );
}
