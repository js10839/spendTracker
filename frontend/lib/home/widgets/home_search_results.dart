import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/components.dart';
import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';
import '../home_format.dart';
import '../home_preview_data.dart';
import '../../data/transactions/transaction_search.dart';

/// 검색어와 선택 범주에 맞는 홈 예시 결과를 표시한다.
class HomeSearchResults extends StatelessWidget {
  const HomeSearchResults({
    super.key,
    required this.search,
    required this.card,
    required this.month,
    required this.searchCategory,
    required this.onCategoryChanged,
    this.liveResult,
    this.methodColors = const {},
    this.rangeLabel,
  });
  final String search;
  final int card, searchCategory;
  final DateTime month;
  final ValueChanged<int> onCategoryChanged;
  final TransactionSearchResult? liveResult;
  final Map<String, Color> methodColors;
  final String? rangeLabel;

  /// 달력 아래에 검색한 날짜 수, 합계, 종류별 예시 결과를 표시한다.
  @override
  Widget build(BuildContext context) {
    if (liveResult != null) return _liveResults();
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return const SizedBox.shrink();
    final items = HomePreviewData.searchItems
        .where(
          (item) =>
              (card == 0 || item.card == card) &&
              (item.name.toLowerCase().contains(query) ||
                  item.store.toLowerCase().contains(query)),
        )
        .toList();
    final total = items.fold<int>(0, (sum, item) => sum + item.cents);
    final storeCount = items.map((item) => item.store).toSet().length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTokens.textPrimary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${items.length} days with “${search.trim()}” this month',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppPalette.neutral600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppComponentColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“${search.trim()}” · ${homeMonths[month.month - 1]}',
                      style: AppTypography.bodyMediumStrong.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    Text(
                      '${items.length} items · $storeCount stores',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(formatHomeMoney(total), style: AppTypography.heading2),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < 4; index++)
              AppChip(
                label: const ['All', 'Items', 'Stores', 'Categories'][index],
                tone: searchCategory == index
                    ? AppChipTone.income
                    : AppChipTone.neutral,
                onTap: () => onCategoryChanged(index),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, AppSpacing.lg, 18, 10),
          decoration: BoxDecoration(
            color: AppComponentColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                const [
                  'Items',
                  'Items',
                  'Stores',
                  'Categories',
                ][searchCategory],
                style: AppTypography.bodyMediumStrong,
              ),
              if (searchCategory <= 1)
                for (final item in items) _searchItem(item)
              else if (searchCategory == 2)
                for (final store in items.map((item) => item.store).toSet())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(store, style: AppTypography.bodyMediumStrong),
                  )
              else if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('Dining', style: AppTypography.bodyMediumStrong),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 서버 검색 응답의 합계와 일치한 품목·가게·카테고리를 표시한다.
  Widget _liveResults() {
    final result = liveResult!;
    final filtered = searchCategory == 0 ? result.items : result.items.where((item) => item.matchedFields.contains(const ['', 'item', 'store', 'category'][searchCategory])).toList();
    final stores = {for (final item in filtered) if (item.merchant != null && item.merchant!.isNotEmpty) item.merchant!};
    final categories = {for (final item in filtered) item.category};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${result.dates.length} days with “${search.trim()}”', style: AppTypography.caption.copyWith(color: AppPalette.neutral600)),
      const SizedBox(height: AppSpacing.sm),
      Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: AppSpacing.lg), decoration: BoxDecoration(color: AppComponentColors.surface, borderRadius: BorderRadius.circular(18)), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('“${search.trim()}” · ${rangeLabel ?? homeMonths[month.month - 1]}', style: AppTypography.bodyMediumStrong.copyWith(color: AppTokens.textSecondary)), Text('${result.itemCount} items · ${result.storeCount} stores', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary))])),
        Text(formatHomeMoney(result.totalCents), style: AppTypography.heading2),
      ])),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: 6, runSpacing: 6, children: [for (var index = 0; index < 4; index++) AppChip(label: const ['All', 'Items', 'Stores', 'Categories'][index], tone: searchCategory == index ? AppChipTone.income : AppChipTone.neutral, onTap: () => onCategoryChanged(index))]),
      const SizedBox(height: AppSpacing.sm),
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(18, AppSpacing.lg, 18, 10), decoration: BoxDecoration(color: AppComponentColors.surface, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(const ['Items', 'Items', 'Stores', 'Categories'][searchCategory], style: AppTypography.bodyMediumStrong),
        if (filtered.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text('No results', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary)))
        else if (searchCategory <= 1) for (final item in filtered) _liveItem(item)
        else if (searchCategory == 2) for (final store in stores) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(store, style: AppTypography.bodyMediumStrong))
        else for (final category in categories) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(category, style: AppTypography.bodyMediumStrong)),
      ])),
    ]);
  }

  /// 검색 품목은 실제 카테고리와 날짜·결제수단 색상으로 표시한다.
  Widget _liveItem(TransactionSearchItem item) => Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Row(children: [
    AppCategoryIcon(category: item.category), const SizedBox(width: AppSpacing.md),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMediumStrong), Row(children: [
      if (methodColors[item.transactionId] case final color?) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5)],
      Flexible(child: Text('${item.merchant ?? ''} · ${homeMonths[item.date.month - 1]} ${item.date.day}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: AppTokens.textSecondary))),
    ])])), const SizedBox(width: AppSpacing.sm), Text(formatHomeMoney(item.cents), style: AppTypography.bodyMediumStrong),
  ]));

  /// Figma의 검색 결과 행에 품목, 매장·날짜와 금액을 표시한다.
  Widget _searchItem(
    ({String name, String store, int day, int cents, int card}) item,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SvgPicture.asset(
            'assets/home/imgIconDining.svg',
            width: 16,
            height: 16,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMediumStrong,
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: HomePreviewData.cardColors[item.card],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${item.store} · Aug ${item.day}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatHomeMoney(item.cents),
          style: AppTypography.bodyMediumStrong,
        ),
      ],
    ),
  );
}
