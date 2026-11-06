import 'package:flutter/material.dart';

import '../../design_system/components.dart';
import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';
import '../home_preview_data.dart';

/// 홈에 맞는 날짜 칸과 범례를 공통 월 달력에 제공한다.
class HomeCalendar extends StatelessWidget {
  const HomeCalendar({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.card,
    required this.view,
    required this.showSearch,
    required this.search,
    required this.onDateSelected,
  });
  final DateTime month, selectedDate;
  final int card, view;
  final bool showSearch;
  final String search;
  final ValueChanged<DateTime> onDateSelected;

  @override
  /// 홈의 날짜 표현을 공통 월 달력에 연결한다.
  Widget build(BuildContext context) => AppMonthCalendar(
    month: month,
    selectedDate: selectedDate,
    onDateSelected: onDateSelected,
    dayBuilder: _dayCell,
  );

  /// 선택일·급여일·마감일과 보기 모드에 따라 날짜 칸을 구분한다.
  Widget _dayCell(
    BuildContext context,
    DateTime date,
    bool enabled,
    bool selected,
  ) {
    final previewMonth = date.year == 2026 && date.month == 8;
    final dayAmount = previewMonth
        ? HomePreviewData.dailyAmounts[date.day]
        : null;
    final payday = previewMonth && date.day == 1;
    final closing = previewMonth && date.day == 15;
    final today = previewMonth && date.day == 24;
    final future = previewMonth && date.day > 24;
    final searchMatch =
        showSearch &&
        search.trim().isNotEmpty &&
        HomePreviewData.searchItems.any(
          (item) =>
              item.day == date.day &&
              (card == 0 || item.card == card) &&
              (item.name.toLowerCase().contains(search.trim().toLowerCase()) ||
                  item.store.toLowerCase().contains(
                    search.trim().toLowerCase(),
                  )),
        );
    final dayDots = previewMonth
        ? HomePreviewData.dailyDots[date.day] ?? const <Color>[]
        : const <Color>[];
    final visibleDots = card == 0
        ? dayDots
        : dayDots
              .where((color) => color == HomePreviewData.cardColors[card])
              .toList();
    final borderColor = searchMatch
        ? AppTokens.textPrimary
        : date.day == 5 && previewMonth
        ? AppPalette.accentBlue
        : closing
        ? AppPalette.accentSky
        : future
        ? AppTokens.borderSubtle
        : null;
    final dayLabel = Text(
      '${date.day}',
      maxLines: 1,
      style: (view == 0 ? AppTypography.bodyMedium : AppTypography.caption)
          .copyWith(
            color: today
                ? AppTokens.textInverse
                : closing
                ? AppTokens.textPrimary
                : future
                ? AppTokens.textDisabled
                : AppTokens.textSecondary,

            height: view == 0 ? 1.5 : null,
          ),
    );
    return Container(
      key: Key('home-day-${date.day}'),
      padding: closing
          ? const EdgeInsets.fromLTRB(6, 6, 6, AppSpacing.xs)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: today
            ? AppTokens.brandPurple
            : payday || closing
            ? AppTokens.brandLime.withValues(alpha: .4)
            : future
            ? AppTokens.background
            : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      // 테두리를 겹쳐 그려 60px 칸 안의 Figma 패딩을 줄이지 않는다.
      foregroundDecoration: borderColor == null
          ? null
          : BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: future && !searchMatch ? 1 : 1.5,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (view == 0)
            SizedBox(
              width: double.infinity,
              height: 21,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: dayLabel,
              ),
            )
          else
            dayLabel,
          if (dayAmount != null && (view == 1 || date.day == 5 || closing)) ...[
            SizedBox(height: closing ? 1 : 2),
            SizedBox(
              height: closing ? 14 : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '\$$dayAmount',
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    color: today
                        ? AppTokens.textInverse
                        : AppTokens.textPrimary,

                    height: closing ? 1.17 : 1.4,
                  ),
                ),
              ),
            ),
            if (closing && view == 1) ...[
              const SizedBox(height: 1),
              // 마감일의 세 줄을 60px 안에 맞추되 실제 글자 스타일은 유지한다.
              SizedBox(
                height: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+2.4k',
                    style: AppTypography.caption.copyWith(
                      color: AppTokens.textPrimary,

                      height: 1.17,
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (visibleDots.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < visibleDots.length; index++) ...[
                  if (index > 0) const SizedBox(width: 3),
                  Container(
                    key: Key('home-day-${date.day}-dot-$index'),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: visibleDots[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Simple은 마감일 설명만, Detail은 카드·급여·마감일·오늘 범례를 표시한다.
  Widget legend() {
    if (view == 0) {
      if (card != 0 && HomePreviewData.closingDays[card] == null) {
        return const SizedBox.shrink();
      }
      final closingColor = card == 0
          ? AppPalette.accentSky
          : HomePreviewData.cardColors[card];
      return Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('home-simple-closing-marker'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTokens.surface,
                border: Border.all(color: closingColor, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Closing date (cycle total, in card color)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final visibleCards = card == 0 ? [1, 2, 3, 4] : [card];
    final closingColors = [
      for (final card in visibleCards)
        if (HomePreviewData.closingDays[card] != null)
          HomePreviewData.cardColors[card],
    ];
    final labelStyle = AppTypography.caption.copyWith(
      color: AppTokens.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            key: const Key('home-legend-methods'),
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var position = 0;
                  position < visibleCards.length;
                  position++
                ) ...[
                  if (position > 0) const SizedBox(width: AppSpacing.md),
                  _legendItem(
                    visibleCards[position] == 4
                        ? 'Debit'
                        : HomePreviewData.cardNames[visibleCards[position]],
                    HomePreviewData.cardColors[visibleCards[position]],
                  ),
                ],
                const SizedBox(width: AppSpacing.md),
                _legendItem('Payday', AppTokens.brandLime),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (closingColors.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var index = 0;
                      index < closingColors.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 2),
                      Container(
                        key: Key('home-closing-marker-$index'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTokens.surface,
                          border: Border.all(
                            color: closingColors[index],
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                    const SizedBox(width: 5),
                    Text('Closing day', style: labelStyle),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Container(
                key: const Key('home-today-marker'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTokens.brandPurple,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text('Today', style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }

  /// 범례 한 항목의 색 점과 이름을 배치한다.
  Widget _legendItem(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: AppTypography.caption.copyWith(color: AppTokens.textSecondary),
      ),
    ],
  );
}
