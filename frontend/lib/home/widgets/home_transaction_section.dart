import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/components.dart';
import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';
import '../home_format.dart';
import '../home_preview_data.dart';

/// 선택한 날짜의 요약과 거래별 품목 및 메모를 표시한다.
class HomeTransactionSection extends StatelessWidget {
  const HomeTransactionSection({
    super.key,
    required this.selectedDate,
    required this.card,
    required this.view,
    required this.expanded,
    required this.expandedTransactions,
    required this.notes,
    required this.merchantNotes,
    required this.onExpand,
    required this.onCollapse,
    required this.onCollapseAll,
    required this.onToggleTransaction,
    required this.onOpenNoteEditor,
  });
  final DateTime selectedDate;
  final int card, view;
  final bool expanded;
  final Set<int> expandedTransactions;
  final Map<DateTime, String> notes;
  final Map<(DateTime, String), String> merchantNotes;
  final VoidCallback onExpand, onCollapse, onCollapseAll;
  final ValueChanged<int> onToggleTransaction;
  final ValueChanged<String?> onOpenNoteEditor;

  /// 선택 날짜의 거래를 All 또는 선택한 결제수단으로 좁힌다.
  List<HomePreviewTransaction> get _selectedTransactions {
    final transactions = HomePreviewData.transactionsFor(selectedDate);
    return card == 0
        ? transactions
        : transactions
              .where((transaction) => transaction.card == card)
              .toList();
  }

  /// 날짜를 탭하면 필터에 맞는 지출 요약과 예시 거래를 펼쳐 보여준다.
  @override
  Widget build(BuildContext context) {
    final isToday =
        selectedDate.year == 2026 &&
        selectedDate.month == 8 &&
        selectedDate.day == 24;
    final transactions = _selectedTransactions;
    final totalCents = transactions.fold<int>(
      0,
      (sum, transaction) => sum + transaction.cents,
    );
    if (!expanded) {
      return _collapsedDaySummary(isToday, totalCents);
    }
    final methodCount = transactions
        .map((transaction) => transaction.card)
        .toSet()
        .length;
    final itemCount = transactions.fold<int>(
      0,
      (sum, transaction) => sum + transaction.itemCount,
    );
    final weekday = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][selectedDate.weekday - 1];
    return Container(
      key: const Key('home-day-summary'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        18,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTokens.background,
        border: Border.all(color: AppTokens.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('home-day-detail-toggle'),
            onTap: onCollapse,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$weekday, ${homeMonths[selectedDate.month - 1]} ${selectedDate.day}',
                          style: AppTypography.bodyMediumStrong,
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 168),
                          child: Text(
                            '$methodCount payment method${methodCount == 1 ? '' : 's'} · '
                            '$itemCount item${itemCount == 1 ? '' : 's'}',
                            key: const Key('home-day-detail-count'),
                            style: AppTypography.caption.copyWith(
                              color: AppTokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                Text(
                  formatHomeMoney(totalCents),
                  style: AppTypography.heading2,
                ),
                const SizedBox(width: 6),
                const AppChevronDown(key: Key('home-day-detail-chevron')),
              ],
            ),
          ),
          if (transactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                key: const Key('home-day-method-bar'),
                height: 8,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < transactions.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: transactions[index].cents > 0
                            ? transactions[index].cents
                            : 1,
                        child: ColoredBox(
                          color: switch (transactions[index].card) {
                            3 => AppPalette.neutral400,
                            4 => AppTokens.textPrimary,
                            _ =>
                              HomePreviewData.cardColors[transactions[index]
                                  .card],
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          for (final (index, transaction) in transactions.indexed) ...[
            const SizedBox(height: 10),
            Divider(
              key: Key('home-day-divider-$index-${transaction.merchant}'),
              height: 1,
              color: AppTokens.borderSubtle,
            ),
            const SizedBox(height: 10),
            _merchant(transaction, index, index == 0),
          ],
          if (expandedTransactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              key: const Key('home-day-collapse-all'),
              onTap: onCollapseAll,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: AppTokens.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Collapse All',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppPalette.neutral600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 접힌 거래 카드는 보기 모드에 따라 카드 칩이나 간결한 금액 행을 표시한다.
  Widget _collapsedDaySummary(bool isToday, int totalCents) {
    final simple = view == 0;
    final transactions = _selectedTransactions;
    final dateLabel = isToday
        ? 'Today · Aug 24'
        : '${homeMonths[selectedDate.month - 1]} ${selectedDate.day}';
    final amountLabel = formatHomeMoney(totalCents);
    final cardIndices = transactions
        .map((transaction) => transaction.card)
        .toSet()
        .toList();
    final chips = <Widget>[
      if (card == 0) ...[
        for (final card in cardIndices.take(2))
          AppChip(
            label: HomePreviewData.cardNames[card],
            size: AppChipSize.compact,
            leadingColor: HomePreviewData.cardColors[card],
          ),
        if (cardIndices.length > 2)
          AppChip(
            label: '+${cardIndices.length - 2}',
            size: AppChipSize.compact,
          ),
      ] else if (transactions.isNotEmpty)
        AppChip(
          label: HomePreviewData.cardNames[card],
          size: AppChipSize.compact,
          leadingColor: HomePreviewData.cardColors[card],
        ),
    ];
    final editIcon = Semantics(
      button: true,
      label: 'Edit note',
      child: GestureDetector(
        onTap: () => onOpenNoteEditor(null),
        child: Container(
          key: const Key('home-day-edit-icon'),
          width: simple ? 30 : 28,
          height: simple ? 30 : 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                (notes[DateUtils.dateOnly(selectedDate)]?.trim().isNotEmpty ??
                    false)
                ? AppTokens.brandLime
                : AppTokens.surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: SvgPicture.asset(
            'assets/home/imgIconPencil.svg',
            width: 14,
            height: 14,
          ),
        ),
      ),
    );
    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        key: const Key('home-day-summary'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppTokens.background,
          border: Border.all(color: AppTokens.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Builder(
          builder: (context) {
            if (simple) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(amountLabel, style: AppTypography.heading3),
                  const SizedBox(width: 10),
                  editIcon,
                ],
              );
            }
            final dateAndAmount = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: AppTypography.caption.copyWith(
                    color: AppTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(amountLabel, style: AppTypography.heading3),
              ],
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                dateAndAmount,
                const SizedBox(width: 6),
                if (chips.isNotEmpty) Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < chips.length; index++) ...[
                          if (index > 0) const SizedBox(width: 6),
                          chips[index],
                        ],
                      ],
                    ),
                  ),
                ),
                if (chips.isNotEmpty) const SizedBox(width: 6),
                if (chips.isEmpty) const Spacer(),
                editIcon,
              ],
            );
          },
        ),
      ),
    );
  }

  /// 가게 행을 누르면 품목을 펼치고, 메모가 있으면 접힌 상태에도 보여준다.
  Widget _merchant(
    HomePreviewTransaction transaction,
    int index,
    bool showsDayNote,
  ) {
    final expanded = expandedTransactions.contains(index);
    final date = DateUtils.dateOnly(selectedDate);
    final note = showsDayNote
        ? notes[date]
        : merchantNotes[(date, transaction.merchant)];
    final methodAsset = const [
      '',
      'imgDayMethodChase.svg',
      'imgDayMethodAmex.svg',
      'imgDayMethodCash.svg',
      'imgDayMethodDebit.svg',
    ][transaction.card];
    return Column(
      key: Key('home-merchant-group-$index'),
      children: [
        InkWell(
          key: Key('home-merchant-$index-${transaction.merchant}'),
          onTap: () => onToggleTransaction(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/home/$methodAsset',
                  key: Key('home-merchant-icon-$index-${transaction.merchant}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchant,
                        style: AppTypography.bodyMediumStrong,
                      ),
                      Text(
                        '${HomePreviewData.cardNames[transaction.card]} · '
                        '${transaction.itemCount} item${transaction.itemCount == 1 ? '' : 's'}',
                        style: AppTypography.caption.copyWith(
                          color: AppTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatHomeMoney(transaction.cents),
                  style: AppTypography.bodyMediumStrong,
                ),
                const SizedBox(width: 6),
                SvgPicture.asset(
                  'assets/home/${expanded ? 'imgDayChevronUp.svg' : 'imgDayChevron.svg'}',
                  key: Key('home-merchant-chevron-$index'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final item in HomePreviewData.itemsFor(transaction)) _item(item),
        if ((note?.trim().isNotEmpty ?? false) || expanded) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 2),
            child: note?.trim().isNotEmpty ?? false
                ? InkWell(
                    onTap: () => onOpenNoteEditor(
                      showsDayNote ? null : transaction.merchant,
                    ),
                    child: Container(
                      key: Key(
                        'home-merchant-note-$index-${transaction.merchant}',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset('assets/home/imgDayPencil.svg'),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => onOpenNoteEditor(
                        showsDayNote ? null : transaction.merchant,
                      ),
                      child: Text(
                        '+ Add note',
                        style: AppTypography.bodyMediumStrong.copyWith(
                          color: AppPalette.purple500,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  /// 품목명과 카테고리는 왼쪽에서 줄바꿈하고 금액은 오른쪽 20px 패딩에 맞춘다.
  Widget _item(HomePreviewItem item) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.category,
        style: AppTypography.labelSmall.copyWith(color: AppPalette.neutral600),
      ),
    );
    final amount = Text(
      formatHomeMoney(item.cents),
      key: Key('home-item-amount-${item.name}'),
      style: AppTypography.bodyMedium.copyWith(color: AppPalette.neutral600),
    );
    return Padding(
      key: Key('home-item-${item.name}'),
      padding: const EdgeInsets.only(left: 44, top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCategoryIcon(category: item.category),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  item.name,
                  softWrap: true,
                  style: AppTypography.bodyMedium.copyWith(
                    color: item.category == 'Tax & Tip'
                        ? AppTokens.textSecondary
                        : AppTokens.textPrimary,
                  ),
                ),
                badge,
              ],
            ),
          ),
          const SizedBox(width: 6),
          amount,
        ],
      ),
    );
  }
}
