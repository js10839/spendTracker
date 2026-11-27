import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../home/home_format.dart';
import 'dashboard_repository.dart';
import 'dashboard_motion.dart';

class DashboardPeriodSwitch extends StatelessWidget {
  const DashboardPeriodSwitch({
    super.key,
    required this.rolling,
    required this.today,
    required this.month,
    required this.onToggle,
    required this.onSettled,
    required this.onPickMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final bool rolling;
  final DateTime today;
  final DateTime month;
  final VoidCallback onToggle;
  final VoidCallback onSettled;
  final VoidCallback onPickMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final start = dashboardRollingStart(today);
    final dateRange = '(${_shortDate(start)} – ${_shortDate(today)})';
    final height = MediaQuery.textScalerOf(context)
        .scale(24)
        .clamp(_size, 72.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth - AppSpacing.sm - _size;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: rolling ? 1.0 : 0.0, end: rolling ? 1.0 : 0.0),
          duration: dashboardDuration(context, dashboardPeriodDuration),
          curve: dashboardEaseInOut,
          onEnd: onSettled,
          builder: (context, progress, _) {
            final leftWidth = lerpDouble(_size, expanded, progress)!;
            final rightWidth = expanded + _size - leftWidth;
            return Row(
              children: [
                _pill(
                  key: const Key('dashboard-rolling-pill'),
                  width: leftWidth,
                  anchor: Alignment.centerLeft,
                  height: height,
                  expansion: progress,
                  isExpanded: rolling,
                  expandedWidth: expanded,
                  collapsed: _iconButton(
                    'Show past 30 days',
                    'month_clock.svg',
                    onToggle,
                  ),
                  expanded: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          text: 'Past 30 days ',
                          children: [
                            TextSpan(
                              text: dateRange,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTokens.textInverse,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _pill(
                  key: const Key('dashboard-month-pill'),
                  width: rightWidth,
                  anchor: Alignment.centerRight,
                  height: height,
                  expansion: 1 - progress,
                  isExpanded: !rolling,
                  expandedWidth: expanded,
                  collapsed: _iconButton(
                    'Show calendar month',
                    'period_calendar.svg',
                    onToggle,
                  ),
                  expanded: Row(
                    children: [
                      _iconButton(
                        'Previous month',
                        'month_previous.svg',
                        onPreviousMonth,
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: onPickMonth,
                          child: Text(
                            '${homeMonths[month.month - 1]} ${month.year}',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppTokens.textInverse,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      _iconButton('Next month', 'month_next.svg', onNextMonth),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _pill({
    required Key key,
    required double width,
    required Alignment anchor,
    required double height,
    required double expansion,
    required bool isExpanded,
    required double expandedWidth,
    required Widget collapsed,
    required Widget expanded,
  }) {
    final labelOpacity = expansion;
    final iconOpacity = 1 - expansion;
    return SizedBox(
      key: key,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            AppTokens.surface,
            AppTokens.brandPurple,
            expansion,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: AppComponentColors.shadowPurple.withValues(
                alpha: .18 * expansion,
              ),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (labelOpacity > 0)
                  IgnorePointer(
                    ignoring: !isExpanded,
                    child: ExcludeSemantics(
                      excluding: !isExpanded,
                      child: Opacity(
                        opacity: labelOpacity,
                        child: OverflowBox(
                          alignment: anchor,
                          minWidth: expandedWidth,
                          maxWidth: expandedWidth,
                          child: expanded,
                        ),
                      ),
                    ),
                  ),
                if (iconOpacity > 0)
                  IgnorePointer(
                    ignoring: isExpanded,
                    child: ExcludeSemantics(
                      excluding: isExpanded,
                      child: Opacity(
                        opacity: iconOpacity,
                        child: Align(
                          alignment: anchor,
                          child: SizedBox(width: _size, child: collapsed),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(String label, String asset, VoidCallback action) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: _size, height: _size),
        icon: SvgPicture.asset('assets/dashboard/$asset'),
      );

  String _shortDate(DateTime date) =>
      '${homeMonths[date.month - 1]} ${date.day}';
}
