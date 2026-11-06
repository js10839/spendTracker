import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/components.dart';
import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';
import '../home_format.dart';
import '../home_preview_data.dart';

/// 헤더에서 순서대로 보여 줄 금액 종류다.
enum HomeTotalMode { spending, net, income }

/// 홈의 금액과 필터, 월 선택 및 검색 컨트롤을 표시한다.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.amount,
    required this.income,
    required this.totalMode,
    required this.onTotalTap,
    required this.card,
    required this.view,
    required this.month,
    required this.showSearch,
    required this.search,
    required this.filterLink,
    required this.monthLink,
    required this.filterAnchorKey,
    required this.monthAnchorKey,
    required this.monthControlWidth,
    required this.onViewChanged,
    required this.onOpenFilter,
    required this.onOpenMonthPicker,
    required this.onMoveMonth,
    required this.onOpenSearch,
    required this.onCancelSearch,
    required this.onSearchChanged,
  });
  final int amount, income, card, view;
  final HomeTotalMode totalMode;
  final VoidCallback onTotalTap;
  final DateTime month;
  final bool showSearch;
  final TextEditingController search;
  final LayerLink filterLink, monthLink;
  final GlobalKey filterAnchorKey, monthAnchorKey;
  final double monthControlWidth;
  final ValueChanged<int> onViewChanged, onMoveMonth;
  final VoidCallback onOpenFilter,
      onOpenMonthPicker,
      onOpenSearch,
      onCancelSearch;
  final ValueChanged<String> onSearchChanged;

  /// 수입 화면에서 밝은 배경에 맞는 컨트롤을 사용한다.
  bool get _lightHeader => totalMode == HomeTotalMode.income;
  /// 배경에 맞춰 헤더 텍스트의 기본 색을 정한다.
  Color get _controlColor => _lightHeader ? AppTokens.textPrimary : AppTokens.textInverse;

  /// Figma의 금액, 보기 전환, 필터 및 월 선택 도구를 헤더에 배치한다.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      18,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      switch (totalMode) {
                        HomeTotalMode.spending => card == 0 ? 'Spent this month' : '8/5~9/4',
                        HomeTotalMode.net => 'Total Spending + Income',
                        HomeTotalMode.income => 'Total Income',
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: _controlColor.withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                  AppSegmentedControl(
                    selectedIndex: view,
                    tone: _lightHeader ? AppSegmentedControlTone.onLightColor : AppSegmentedControlTone.onColor,
                    onChanged: onViewChanged,
                  ),
                ],
              ),
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const Key('home-total-amount'),
                  onTap: onTotalTap,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatHomeMoney(switch (totalMode) {
                        HomeTotalMode.spending => amount,
                        HomeTotalMode.net => income - amount,
                        HomeTotalMode.income => income,
                      }),
                      style: AppTypography.displayAmount.copyWith(color: _controlColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _filterButton(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: showSearch ? _searchField(context) : _monthSwitcher(),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (showSearch)
              TextButton(
                onPressed: onCancelSearch,
                style: TextButton.styleFrom(
                  foregroundColor: _controlColor,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(52, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cancel',
                  style: AppTypography.bodyLarge.copyWith(
                    color: _controlColor,
                  ),
                ),
              )
            else
              _headerCircle('imgIconSearch.svg', onOpenSearch),
          ],
        ),
      ],
    ),
  );

  /// 필터 버튼의 위치를 시트가 열린 동안 강조 표시와 연결한다.
  Widget _filterButton() => CompositedTransformTarget(
    key: filterAnchorKey,
    link: filterLink,
    child: filterPill(key: const Key('home-card-filter'), onTap: onOpenFilter),
  );

  /// 헤더와 강조 표시가 같은 40픽셀 필터 캡슐을 그린다.
  Widget filterPill({Key? key, VoidCallback? onTap}) => Material(
    key: key,
    color: _lightHeader ? AppTokens.brandPurple : AppTokens.brandLime,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg, right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                HomePreviewData.cardNames[card],
                style: AppTypography.bodyLarge.copyWith(color: _lightHeader ? AppTokens.textInverse : AppTokens.textPrimary),
              ),
              const SizedBox(width: 6),
              SvgPicture.asset(
                'assets/home/imgIconFilter.svg',
                width: 18,
                height: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// 월 선택 캡슐의 위치를 시트의 강조 표시와 연결한다.
  Widget _monthSwitcher() => CompositedTransformTarget(
    key: monthAnchorKey,
    link: monthLink,
    child: _monthPill(key: const Key('home-month-switcher')),
  );

  /// 월 캡슐의 위치와 크기는 유지하고 시트가 열리면 색만 바꾼다.
  Widget _monthPill({Key? key, bool active = false}) => Container(
    key: key,
    height: 40,
    decoration: BoxDecoration(
      color: active
          ? AppTokens.background
          : AppTokens.background.withValues(alpha: _lightHeader ? 0.35 : 0.18),
      border: Border.all(color: _lightHeader ? AppTokens.textPrimary : AppTokens.textInverse, width: _lightHeader ? 1 : 1.2),
      borderRadius: BorderRadius.circular(AppRadius.full),
      boxShadow: [AppShadows.headerControl],
    ),
    child: Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34),
          icon: SvgPicture.asset(
            active
                ? 'assets/home/imgMonthPickerPrev.svg'
                : 'assets/home/imgPrev.svg',
            width: 7,
            height: 12,
            colorFilter: _lightHeader && !active ? const ColorFilter.mode(AppTokens.textPrimary, BlendMode.srcIn) : null,
          ),
          onPressed: () => onMoveMonth(-1),
        ),
        Expanded(
          child: InkWell(
            onTap: onOpenMonthPicker,
            child: Center(
              child: Text(
                _monthLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLarge.copyWith(
                  color: active ? AppTokens.textPrimary : _controlColor,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34),
          icon: SvgPicture.asset(
            active
                ? 'assets/home/imgMonthPickerNext.svg'
                : 'assets/home/imgNext.svg',
            width: 7,
            height: 12,
            colorFilter: _lightHeader && !active ? const ColorFilter.mode(AppTokens.textPrimary, BlendMode.srcIn) : null,
          ),
          onPressed: () => onMoveMonth(1),
        ),
      ],
    ),
  );

  /// 원본 캡슐과 같은 폭으로 선택 상태를 겹쳐 표시한다.
  Widget activeMonthSwitcher() => SizedBox(
    width: monthControlWidth,
    child: _monthPill(key: const Key('home-month-highlight'), active: true),
  );

  /// 헤더와 강조 표시에서 같은 월 문구를 사용한다.
  String get _monthLabel => card == 0
      ? '${homeMonths[month.month - 1]} ${month.year}'
      : '${homeMonths[month.month - 1]} - ${homeMonths[month.month % 12]} ${month.year}';

  /// 헤더의 원형 아이콘 버튼을 Figma 크기로 만든다.
  Widget _headerCircle(String asset, VoidCallback onTap) => InkWell(
    key: const Key('home-search-button'),
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTokens.background.withValues(alpha: _lightHeader ? 0.35 : 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: _controlColor, width: _lightHeader ? 1 : 1.2),
        boxShadow: [AppShadows.headerControl],
      ),
      child: SvgPicture.asset('assets/home/$asset', width: 18, height: 18),
    ),
  );

  /// 달력 위의 검색창을 카드 필터와 같은 헤더 줄에 표시한다.
  Widget _searchField(BuildContext context) => Container(
    key: const Key('home-search-field'),
    height: 40,
    padding: const EdgeInsets.only(left: 14, right: 18),
    decoration: BoxDecoration(
      color: AppTokens.background.withValues(alpha: _lightHeader ? 0.35 : 0.18),
      border: Border.all(color: _controlColor, width: _lightHeader ? 1 : 1.2),
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      children: [
        SvgPicture.asset(
          'assets/home/imgIconSearch.svg',
          width: 18,
          height: 18,
          colorFilter: _lightHeader ? const ColorFilter.mode(AppTokens.textPrimary, BlendMode.srcIn) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            onChanged: onSearchChanged,
            cursorColor: _controlColor,
            style: AppTypography.bodyLarge.copyWith(
              color: _controlColor,
            ),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: _controlColor.withValues(alpha: 0.70),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );
}
