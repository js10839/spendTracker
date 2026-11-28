import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../home/home_format.dart';
import 'dashboard_repository.dart';
import 'dashboard_motion.dart';

typedef DashboardCashMonth = ({DateTime date, int income, int spending});

class DashboardAnalytics extends StatelessWidget {
  const DashboardAnalytics({
    super.key,
    required this.summary,
    required this.cashFlow,
    required this.onRetryCashFlow,
    required this.rolling,
  });

  final DashboardSummary summary;
  final Future<List<DashboardCashMonth>?> cashFlow;
  final VoidCallback onRetryCashFlow;
  final bool rolling;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.md,
    children: [
      Hero(
        tag: dashboardCardHero,
        curve: dashboardEaseInOut,
        flightShuttleBuilder: dashboardSurfaceFlight,
        child: Material(
          type: MaterialType.transparency,
          child: _SpendingCard(
            daily: summary.daily,
            yearly: summary.yearly,
            rolling: rolling,
          ),
        ),
      ),
      _BreakdownCard(title: 'By card', rows: summary.paymentMethods),
      _BreakdownCard(title: 'Category breakdown', rows: summary.categories),
      Text('Income vs spending', style: AppTypography.bodyMediumStrong),
      FutureBuilder<List<DashboardCashMonth>?>(
        future: cashFlow,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DashboardCard(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final months = snapshot.data;
          if (months == null || months.isEmpty) {
            return _DashboardCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cash flow unavailable',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: onRetryCashFlow,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          return _CashFlowCard(months: months);
        },
      ),
    ],
  );
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTokens.background,
      border: Border.all(color: const Color(0xFFDFDFDF)),
      borderRadius: BorderRadius.circular(AppSpacing.twoXL),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: child,
    ),
  );
}

class _SpendingCard extends StatefulWidget {
  const _SpendingCard({
    required this.daily,
    required this.yearly,
    required this.rolling,
  });

  final List<DashboardBucket> daily;
  final List<DashboardBucket> yearly;
  final bool rolling;

  @override
  State<_SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends State<_SpendingCard> {
  int _range = 0;
  int? _selected;

  List<DashboardBucket> _weeks() {
    final weekly = <DateTime, int>{};
    for (final day in widget.daily) {
      final sunday = day.date.subtract(Duration(days: day.date.weekday % 7));
      final start = sunday.isBefore(widget.daily.first.date)
          ? widget.daily.first.date
          : sunday;
      weekly.update(start, (sum) => sum + day.cents, ifAbsent: () => day.cents);
    }
    return [
      for (final week in weekly.entries) (date: week.key, cents: week.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final buckets = switch (_range) {
      1 => _weeks(),
      2 => widget.yearly,
      _ => widget.daily,
    };

    final details = [
      for (final bucket in buckets)
        (name: _dateLabel(bucket.date, _range), amount: bucket.cents),
    ];

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: AppSpacing.sm,
            children: [
              _DetailsButton(
                title: 'Spending',
                rows: details,
                labelStyle: AppTypography.heading3,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SpendingSelector(
                      selection: _range,
                      onChanged: (index) => setState(() {
                        _range = index;
                        _selected = null;
                      }),
                    ),
                    _DetailsButton(title: 'Spending', rows: details),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: dashboardDuration(context, dashboardSpendingDuration),
            switchInCurve: dashboardEaseInOut,
            switchOutCurve: dashboardEaseInOut,
            child: buckets.every((bucket) => bucket.cents == 0)
                ? Padding(
                    key: ValueKey(_range),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.twoXL,
                    ),
                    child: Text('No spending for this period', style: _caption),
                  )
                : _SpendingChart(
                    key: ValueKey(_range),
                    buckets: buckets,
                    range: _range,
                    rolling: widget.rolling,
                    selected: _selected,
                    onSelected: (index) => setState(
                      () => _selected = _selected == index ? null : index,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpendingSelector extends StatelessWidget {
  const _SpendingSelector({required this.selection, required this.onChanged});

  final int selection;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Day', 'Week', 'Month'];
    final duration = dashboardDuration(context, dashboardSpendingDuration);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width = 58 * scale;
    return Material(
      color: AppComponentColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                key: const Key('dashboard-spending-indicator'),
                alignment: Alignment(selection - 1.0, 0),
                duration: duration,
                curve: dashboardEaseInOut,
                child: SizedBox(
                  width: width,
                  height: double.infinity,
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(
                      color: AppTokens.background,
                      shape: StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, label) in labels.indexed)
                  Semantics(
                    selected: selection == index,
                    button: true,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onChanged(index),
                      child: SizedBox(
                        width: width,
                        height: 28 * scale,
                        child: Center(
                          child: Text(label, style: AppTypography.labelSmall),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart({
    super.key,
    required this.buckets,
    required this.range,
    required this.rolling,
    required this.selected,
    required this.onSelected,
  });

  final List<DashboardBucket> buckets;
  final int range;
  final bool rolling;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final highest = buckets.fold<int>(
      0,
      (value, bucket) => math.max(value, bucket.cents),
    );
    final lowest = buckets.fold<int>(
      0,
      (value, bucket) => math.min(value, bucket.cents),
    );
    final high = _axisLimit(highest);
    final low = lowest == 0 ? 0 : -_axisLimit(-lowest);
    const height = 110.0;
    final span = high - low;
    final zero = height * high / span;
    final marks = [high, if (low < 0) 0 else (high / 2).round(), low];
    final current = selected;
    return Row(
      children: [
        SizedBox(
          width: 48,
          height: height + 24,
          child: Stack(
            children: [
              for (final mark in marks)
                Positioned(
                  top: (height * (high - mark) / span - 8).clamp(0.0, height),
                  child: Text(_axisMoney(mark), style: _caption),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final slot = width / buckets.length;
              final tooltipWidth = math.min(88.0, width);
              return SizedBox(
                height: height + 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final mark in marks)
                      Positioned(
                        top: height * (high - mark) / span,
                        left: 0,
                        right: 0,
                        child: const ColoredBox(
                          color: AppTokens.borderSubtle,
                          child: SizedBox(height: 1),
                        ),
                      ),
                    for (final (index, bucket) in buckets.indexed)
                      Positioned(
                        top: 0,
                        left: index * slot,
                        width: slot,
                        height: height,
                        child: Semantics(
                          button: true,
                          selected: index == current,
                          label:
                              '${_dateLabel(bucket.date, range)}, ${formatHomeMoney(bucket.cents)}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelected(index),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: bucket.cents < 0
                                      ? zero
                                      : zero - height * bucket.cents / span,
                                ),
                                child: Container(
                                  width: math.min(18, slot * .60),
                                  height: height * bucket.cents.abs() / span,
                                  decoration: BoxDecoration(
                                    color: index == current
                                        ? AppTokens.brandPurple
                                        : AppTokens.borderStrong,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final (index, bucket) in buckets.indexed)
                      if (_showTick(index, buckets.length, bucket.date))
                        Positioned(
                          top: height + 7,
                          left: 0,
                          right: 0,
                          child: Align(
                            alignment: Alignment(
                              buckets.length == 1
                                  ? 0
                                  : 2 * index / (buckets.length - 1) - 1,
                              0,
                            ),
                            child: Text(
                              range == 2
                                  ? homeMonths[bucket.date.month - 1]
                                  : rolling
                                  ? '${bucket.date.month}/${bucket.date.day}'
                                  : '${bucket.date.day}',
                              style: _caption,
                            ),
                          ),
                        ),
                    if (current != null && current < buckets.length)
                      Positioned(
                        top:
                            (zero -
                                    height *
                                        math.max(0, buckets[current].cents) /
                                        span -
                                    44)
                                .clamp(0.0, height - 44),
                        left: ((current + .5) * slot - tooltipWidth / 2).clamp(
                          0.0,
                          width - tooltipWidth,
                        ),
                        width: tooltipWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTokens.textPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _dateLabel(buckets[current].date, range),
                                    style: _caption.copyWith(
                                      color: AppTokens.textInverse,
                                    ),
                                  ),
                                  Text(
                                    formatHomeMoney(buckets[current].cents),
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppTokens.textInverse,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _showTick(int index, int count, DateTime date) {
    if (index == 0 || index == count - 1) return true;
    if (range == 2) return index.isEven;
    if (range == 1) return true;
    if (rolling) return index % 7 == 0 && index < count - 3;
    return date.day % 5 == 0 && index < count - 2;
  }
}

int _axisLimit(int cents) {
  if (cents <= 100) return 100;
  final digits = math.pow(10, cents.toString().length - 1).toInt();
  return (cents / digits).ceil() * digits;
}

String _axisMoney(int cents) => cents % 100 == 0
    ? '${cents < 0 ? '−' : ''}\$${cents.abs() ~/ 100}'
    : formatHomeMoney(cents);

String _dateLabel(DateTime date, int range) {
  final month = homeMonths[date.month - 1];
  return range == 2 ? month : '$month ${date.day}';
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.rows});

  final String title;
  final List<DashboardAmount> rows;

  @override
  Widget build(BuildContext context) {
    final positive = rows.where((row) => row.cents > 0).toList();
    final total = positive.fold<int>(0, (value, row) => value + row.cents);
    final credits = rows.any((row) => row.cents < 0);
    final details = [
      for (final row in rows) (name: row.name, amount: row.cents),
    ];
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _DetailsButton(
                  title: title,
                  rows: details,
                  labelStyle: AppTypography.bodyMediumStrong,
                ),
              ),
              if (rows.isNotEmpty) _DetailsButton(title: title, rows: details),
            ],
          ),
          if (rows.isEmpty)
            Text('No spending for this period', style: _caption)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (total > 0) ...[
                  CustomPaint(
                    size: const Size.square(110),
                    painter: _DonutPainter(positive, total),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      for (final row in rows)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: SizedBox.square(
                                dimension: 10,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: row.color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${row.name}${row.cents > 0 ? '  ${(100 * row.cents / total).round()}%' : ''} · ${formatHomeMoney(row.cents)}',
                                style: _caption,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          if (credits && total > 0)
            Text('Shares are based on positive spending.', style: _caption),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.rows, this.total);

  final List<DashboardAmount> rows;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final bounds = (Offset.zero & size).deflate(stroke / 2);
    var angle = -math.pi / 2;
    for (final row in rows) {
      final sweep = 2 * math.pi * row.cents / total;
      final gap = rows.length == 1 ? 0.0 : math.min(.055, sweep / 2);
      canvas.drawArc(
        bounds,
        angle + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = row.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.rows != rows || oldDelegate.total != total;
}

class _DetailsButton extends StatelessWidget {
  const _DetailsButton({
    required this.title,
    required this.rows,
    this.labelStyle,
  });

  final String title;
  final List<({String name, int amount})> rows;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    void open() => pushDashboardDetail<void>(
      context,
      title: title,
      builder: (context) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          if (rows.isEmpty)
            Text('No spending for this period', style: _caption),
          for (final row in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.name, style: AppTypography.bodyMedium),
              trailing: Text(
                formatHomeMoney(row.amount),
                style: AppTypography.bodyMediumStrong,
              ),
            ),
        ],
      ),
    );

    if (labelStyle != null) {
      return InkWell(
        onTap: open,
        child: Text(title, style: labelStyle),
      );
    }
    return IconButton(
      tooltip: '$title details',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 32),
      icon: SvgPicture.asset('assets/dashboard/statement_chevron.svg'),
      onPressed: open,
    );
  }
}

class _CashFlowCard extends StatefulWidget {
  const _CashFlowCard({required this.months});

  final List<DashboardCashMonth> months;

  @override
  State<_CashFlowCard> createState() => _CashFlowCardState();
}

class _CashFlowCardState extends State<_CashFlowCard> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final selected = months.firstWhere(
      (month) => month.date == _selectedDate,
      orElse: () => months.last,
    );
    final maxTotal = math.max(selected.income.abs(), selected.spending.abs());
    final maxNet = months.fold<int>(
      1,
      (value, month) => math.max(value, (month.income - month.spending).abs()),
    );
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Income − Spending', style: _caption),
              TweenAnimationBuilder<int>(
                tween: IntTween(
                  begin: selected.income - selected.spending,
                  end: selected.income - selected.spending,
                ),
                duration: dashboardDuration(context, dashboardCashFlowDuration),
                curve: dashboardEaseInOut,
                builder: (context, cents, _) => Text(
                  _signedMoney(cents),
                  style: AppTypography.heading1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          _CashBar(
            label: 'Income',
            cents: selected.income,
            limit: maxTotal,
            color: AppTokens.brandLime,
            marker: 'income_dot.svg',
          ),
          _CashBar(
            label: 'Spending',
            cents: -selected.spending,
            limit: maxTotal,
            color: AppTokens.brandPurple,
            marker: 'spending_dot.svg',
          ),
          const Divider(height: 1, color: AppTokens.borderSubtle),
          Text('Net by month', style: _caption),
          Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 42,
                child: ColoredBox(
                  color: AppTokens.borderSubtle,
                  child: SizedBox(height: 1),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final month in months)
                    Flexible(
                      child: _CashColumn(
                        month: month,
                        selected: month.date == selected.date,
                        limit: maxNet,
                        onTap: () => setState(() => _selectedDate = month.date),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashBar extends StatelessWidget {
  const _CashBar({
    required this.label,
    required this.cents,
    required this.limit,
    required this.color,
    required this.marker,
  });

  final String label;
  final int cents;
  final int limit;
  final Color color;
  final String marker;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 6,
    children: [
      Row(
        children: [
          SvgPicture.asset('assets/dashboard/$marker'),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: _caption)),
          Text(_signedMoney(cents), style: AppTypography.caption),
        ],
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: ColoredBox(
          color: AppTokens.surface,
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: limit == 0 ? 0 : cents.abs() / limit,
                end: limit == 0 ? 0 : cents.abs() / limit,
              ),
              duration: dashboardDuration(context, dashboardCashFlowDuration),
              curve: dashboardEaseInOut,
              builder: (_, fraction, child) =>
                  FractionallySizedBox(widthFactor: fraction, child: child),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const SizedBox(height: 10),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _CashColumn extends StatelessWidget {
  const _CashColumn({
    required this.month,
    required this.selected,
    required this.limit,
    required this.onTap,
  });

  final DashboardCashMonth month;
  final bool selected;
  final int limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final net = month.income - month.spending;
    final height = net == 0 ? 0.0 : math.max(2.0, 34 * net.abs() / limit);
    final name = homeMonths[month.date.month - 1];
    return Semantics(
      button: true,
      selected: selected,
      label: '$name ${month.date.year}, net ${_signedMoney(net)}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: dashboardDuration(context, dashboardCashFlowDuration),
        curve: dashboardEaseInOut,
        decoration: BoxDecoration(
          color: selected ? AppTokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  spacing: 6,
                  children: [
                    SizedBox(
                      height: 72,
                      width: 16,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: net < 0 ? 36 : 36 - height,
                            height: height,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: net < 0
                                    ? AppTokens.statusDanger
                                    : AppTokens.brandLime,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedDefaultTextStyle(
                      duration: dashboardDuration(
                        context,
                        dashboardCashFlowDuration,
                      ),
                      curve: dashboardEaseInOut,
                      style: selected ? AppTypography.caption : _caption,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _signedMoney(int cents) => cents > 0
    ? '+${formatHomeMoney(cents)}'
    : cents < 0
    ? '−${formatHomeMoney(cents.abs())}'
    : formatHomeMoney(0);

TextStyle get _caption =>
    AppTypography.caption.copyWith(color: AppTokens.textSecondary);
