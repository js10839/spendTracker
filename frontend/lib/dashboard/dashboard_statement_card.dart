import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../home/home_format.dart';
import 'dashboard_repository.dart';

class DashboardStatementCard extends StatelessWidget {
  const DashboardStatementCard({
    super.key,
    required this.statement,
    required this.onTap,
  });

  final DashboardStatement statement;
  final VoidCallback onTap;

  static String shortDate(DateTime date) => '${date.month}/${date.day}';

  @override
  Widget build(BuildContext context) {
    final daysLeft = statement.end.difference(statement.spentThrough).inDays;
    return Material(
      color: AppTokens.background,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFDFDFDF)),
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.twoXL)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statement.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      statement.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMediumStrong,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(switch (daysLeft) {
                    <= 0 => 'Closes today',
                    1 => '1 day left',
                    _ => '$daysLeft days left',
                  }, style: AppTypography.labelSmall),
                  const SizedBox(width: AppSpacing.sm),
                  SvgPicture.asset('assets/dashboard/statement_chevron.svg'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatHomeMoney(statement.totalCents),
                style: AppTypography.heading1,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Statement so far · Cycle ${shortDate(statement.start)} – ${shortDate(statement.end)}',
                style: AppTypography.caption.copyWith(
                  color: AppTokens.textSecondary,
                ),
              ),
              const Spacer(),
              _CycleTimeline(statement: statement),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleTimeline extends StatelessWidget {
  const _CycleTimeline({required this.statement});

  final DashboardStatement statement;

  @override
  Widget build(BuildContext context) {
    final duration = statement.end.difference(statement.start).inDays;
    final progress = duration > 0
        ? (statement.spentThrough.difference(statement.start).inDays / duration)
              .clamp(0.0, 1.0)
              .toDouble()
        : 1.0;
    final days = [
      0,
      for (var offset = 7; offset <= duration - 4; offset += 7) offset,
      if (duration > 0) duration,
    ];
    final lineColor = AppPalette.accentSky;
    final labelStyle = AppTypography.caption.copyWith(
      color: AppTokens.textSecondary,
    );
    final lineTop = MediaQuery.textScalerOf(context).scale(16) + 3;
    final labelsTop = lineTop + 12;

    return ExcludeSemantics(
      child: SizedBox(
        height: labelsTop + MediaQuery.textScalerOf(context).scale(17),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: lineTop,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const SizedBox(height: 4),
                  ),
                ),
                Positioned(
                  top: lineTop,
                  left: 0,
                  width: width * progress,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                for (final day in days) ...[
                  if (day > 0 && day < duration)
                    Positioned(
                      top: lineTop - 3,
                      left: width * day / duration,
                      child: const SizedBox(
                        width: 1,
                        height: 10,
                        child: ColoredBox(color: AppTokens.borderStrong),
                      ),
                    ),
                  Positioned(
                    top: labelsTop,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(
                        duration == 0 ? -1 : 2 * day / duration - 1,
                        0,
                      ),
                      child: Text(
                        DashboardStatementCard.shortDate(
                          statement.start.add(Duration(days: day)),
                        ),
                        style: labelStyle,
                      ),
                    ),
                  ),
                ],
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment(2 * progress - 1, 0),
                    child: Text('Today', style: AppTypography.labelSmall),
                  ),
                ),
                Positioned(
                  top: lineTop - 5,
                  left: (width - 14) * progress,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: lineColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
