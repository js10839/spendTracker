import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

typedef AppCalendarDayBuilder =
    Widget Function(
      BuildContext context,
      DateTime date,
      bool enabled,
      bool selected,
    );

/// 월별 날짜 배치와 선택 동작을 공유하고 날짜 칸의 표현은 화면에 맡긴다.
class AppMonthCalendar extends StatelessWidget {
  const AppMonthCalendar({
    super.key,
    required this.month,
    this.selectedDate,
    this.firstDate,
    this.lastDate,
    this.rangeStart,
    this.rangeEnd,
    this.onDateSelected,
    this.dayBuilder,
    this.weekdayLabels = const [
      'SUN',
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
    ],
    this.weekdayStyle,
    this.dayHeight = 60,
    this.spacing = 4,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final ValueChanged<DateTime>? onDateSelected;
  final AppCalendarDayBuilder? dayBuilder;
  final List<String> weekdayLabels;
  final TextStyle? weekdayStyle;
  final double dayHeight;
  final double spacing;

  @override
  /// 일요일부터 시작하는 월 그리드를 만들고 빈 날짜도 같은 너비로 유지한다.
  Widget build(BuildContext context) {
    assert(weekdayLabels.length == 7);
    assert((rangeStart == null) == (rangeEnd == null));
    final firstDay = rangeStart == null ? DateTime.utc(month.year, month.month) : DateTime.utc(rangeStart!.year, rangeStart!.month, rangeStart!.day);
    final end = rangeEnd == null ? DateTime.utc(month.year, month.month + 1).subtract(const Duration(days: 1)) : DateTime.utc(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day);
    final dayCount = end.difference(firstDay).inDays + 1;
    final leadingDays = firstDay.weekday % 7;
    final weekCount = (leadingDays + dayCount + 6) ~/ 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var index = 0; index < 7; index++) ...[
              if (index > 0) SizedBox(width: spacing),
              Expanded(
                child: Text(
                  weekdayLabels[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style:
                      weekdayStyle ??
                      AppTypography.caption.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: spacing),
        for (var week = 0; week < weekCount; week++) ...[
          if (week > 0) SizedBox(height: spacing),
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++) ...[
                if (weekday > 0) SizedBox(width: spacing),
                Expanded(
                  child: _daySlot(
                    context,
                    week * 7 + weekday - leadingDays + 1,
                    dayCount,
                    firstDay,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// 선택 가능 범위와 선택 상태를 날짜별로 계산해 화면별 칸 표현에 전달한다.
  Widget _daySlot(BuildContext context, int day, int dayCount, DateTime firstDay) {
    if (day < 1 || day > dayCount) return SizedBox(height: dayHeight);

    final utcDate = firstDay.add(Duration(days: day - 1));
    final date = DateTime(utcDate.year, utcDate.month, utcDate.day);
    final enabled =
        (firstDate == null || !date.isBefore(DateUtils.dateOnly(firstDate!))) &&
        (lastDate == null || !date.isAfter(DateUtils.dateOnly(lastDate!)));
    final selected = DateUtils.isSameDay(date, selectedDate);
    final content =
        dayBuilder?.call(context, date, enabled, selected) ??
        Center(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTokens.brandPurple : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${date.day}',
              style: AppTypography.bodyMediumStrong.copyWith(
                color: !enabled
                    ? AppTokens.textDisabled
                    : selected
                    ? AppTokens.background
                    : AppTokens.textPrimary,
              ),
            ),
          ),
        );

    return SizedBox(
      height: dayHeight,
      child: Semantics(
        button: onDateSelected != null,
        enabled: enabled,
        label: '${date.year}-${date.month}-${date.day}',
        child: onDateSelected == null || !enabled
            ? content
            : InkWell(onTap: () => onDateSelected!(date), child: content),
      ),
    );
  }
}
