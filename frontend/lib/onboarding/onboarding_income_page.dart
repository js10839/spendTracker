import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/closing_day_picker.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'closing_cycle.dart';
import 'onboarding_summary.dart';

enum _IncomeFrequency { monthly, weekly, twiceMonthly, irregular }

/// 정기적인 수입 주기와 입금일을 선택한다.
class OnboardingIncomePage extends StatefulWidget {
  const OnboardingIncomePage({
    super.key,
    this.initialStep = 3,
    this.cards = const {},
  });

  final int initialStep;
  final Map<String, int> cards;

  @override
  State<OnboardingIncomePage> createState() => _OnboardingIncomePageState();
}

class _OnboardingIncomePageState extends State<OnboardingIncomePage> {
  static const _labels = ['Monthly', 'Weekly', 'Twice a month', 'Irregular'];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  _IncomeFrequency? _frequency;
  final _selected = <int>[];

  /// 주기를 바꾸면 이전 주기의 선택을 초기화한다.
  void _selectFrequency(_IncomeFrequency value) {
    if (_frequency == value) return;
    setState(() {
      _frequency = value;
      _selected.clear();
    });
  }

  /// 같은 선택은 해제하고 월 2회는 오래된 선택부터 교체한다.
  void _selectDay(int value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        final limit = _frequency == _IncomeFrequency.twiceMonthly ? 2 : 1;
        if (_selected.length == limit) _selected.removeAt(0);
        _selected.add(value);
      }
    });
  }

  /// 선택 주기에서 오늘 이후 가장 가까운 입금일을 계산한다.
  DateTime? _nextDeposit(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (_frequency == _IncomeFrequency.weekly && _selected.isNotEmpty) {
      return today.add(
        Duration(days: (_selected.first - today.weekday + 7) % 7),
      );
    }
    if ((_frequency == _IncomeFrequency.monthly && _selected.length == 1) ||
        (_frequency == _IncomeFrequency.twiceMonthly &&
            _selected.length == 2)) {
      final candidates = [
        for (final day in _selected)
          for (var offset = 0; offset < 2; offset++)
            closingDateForMonth(today.year, today.month + offset, day),
      ]..sort();
      return candidates.firstWhere((date) => !date.isBefore(today));
    }
    return null;
  }

  /// 앞 단계로 돌아간다.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('onboarding-cards');
    }
  }

  /// 선택한 설정을 알림 안내 화면으로 전달한다.
  void _continue() {
    final sorted = _selected.toList()..sort();
    final income = switch (_frequency) {
      _IncomeFrequency.monthly => 'Payday · every ${ordinalDay(sorted.first)}',
      _IncomeFrequency.weekly =>
        'Payday · every ${_weekdayNames[sorted.first - 1]}',
      _IncomeFrequency.twiceMonthly =>
        'Paydays · ${ordinalDay(sorted.first)} and ${ordinalDay(sorted.last)}',
      _IncomeFrequency.irregular => 'Paydays · irregular',
      null => null,
    };
    context.pushNamed(
      'onboarding-reminders',
      extra: OnboardingSummary(cards: widget.cards, income: income),
    );
  }

  /// 수입 설정 없이 알림 안내 화면으로 이동한다.
  void _skip() {
    context.pushNamed(
      'onboarding-reminders',
      extra: OnboardingSummary(cards: widget.cards),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sectionSpacing = _frequency == _IncomeFrequency.irregular
        ? AppSpacing.twoXL
        : 13.0;
    final next = _nextDeposit(today);
    final complete = _frequency == _IncomeFrequency.irregular || next != null;
    final heading = switch (_frequency) {
      null => '',
      _IncomeFrequency.irregular => 'No set schedule? No problem.',
      _IncomeFrequency.monthly when _selected.isEmpty =>
        'Pick the day your money usually lands',
      _IncomeFrequency.weekly when _selected.isEmpty =>
        'Pick the day of the week it comes in',
      _IncomeFrequency.twiceMonthly when _selected.isEmpty =>
        'Pick two days your money usually lands',
      _IncomeFrequency.twiceMonthly when _selected.length == 1 =>
        'Every ${ordinalDay(_selected.first)} and …',
      _IncomeFrequency.weekly => 'Every ${_weekdayNames[_selected.first - 1]}',
      _IncomeFrequency.monthly => 'Every ${ordinalDay(_selected.first)}',
      _IncomeFrequency.twiceMonthly =>
        'Every ${ordinalDay((_selected.toList()..sort()).first)} and ${ordinalDay((_selected.toList()..sort()).last)}',
    };
    final description = switch (_frequency) {
      null => '',
      _IncomeFrequency.irregular => 'Add income in My Wallet when it comes in.',
      _IncomeFrequency.monthly when _selected.isEmpty =>
        "We'll start your spending cycle from this day.",
      _IncomeFrequency.weekly when _selected.isEmpty =>
        'Your weekly cycle will reset on this day.',
      _IncomeFrequency.twiceMonthly when _selected.isEmpty =>
        'Like the 15th and the last day of the month.',
      _IncomeFrequency.twiceMonthly when _selected.length == 1 =>
        'Pick one more day.',
      _ => 'You can add the amount later in My Wallet.',
    };
    final days = next == null
        ? null
        : DateTime.utc(
            next.year,
            next.month,
            next.day,
          ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final nextLabel = next == null
        ? '-'
        : '${_frequency == _IncomeFrequency.weekly ? '${_weekdays[next.weekday - 1]}, ' : ''}${_months[next.month - 1]} ${next.day} · ${days == 0 ? 'Today' : 'In $days ${days == 1 ? 'day' : 'days'}'}';
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppTokens.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      6,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AppBackButton(onPressed: _back),
                            const SizedBox(width: 14),
                            Expanded(
                              child: AppProgress(
                                step: 4,
                                totalSteps: 5,
                                initialStep: widget.initialStep,
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: _skip,
                              child: Text(
                                'Skip',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppTokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: sectionSpacing),
                        Text(
                          'When does money come in?',
                          textAlign: TextAlign.center,
                          style: AppTypography.heading1,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Paycheck, allowance, or any regular money.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppTokens.textSecondary,
                          ),
                        ),
                        SizedBox(height: sectionSpacing),
                        for (var row = 0; row < 2; row++) ...[
                          if (row > 0) const SizedBox(height: 10),
                          Row(
                            children: [
                              for (var column = 0; column < 2; column++) ...[
                                if (column > 0) const SizedBox(width: 10),
                                Expanded(
                                  child: _frequencyTile(row * 2 + column),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (_frequency != null &&
                            _frequency != _IncomeFrequency.irregular) ...[
                          SizedBox(height: sectionSpacing),
                          AppDaySelectionGrid(
                            itemCount: _frequency == _IncomeFrequency.weekly
                                ? 7
                                : 31,
                            itemBuilder: (context, index) {
                              final value = index + 1;
                              return AppDaySelectionTile(
                                key: ValueKey('income-day-$value'),
                                label: _frequency == _IncomeFrequency.weekly
                                    ? _weekdays[index]
                                    : '$value',
                                selected: _selected.contains(value),
                                today: _frequency == _IncomeFrequency.weekly
                                    ? today.weekday == value
                                    : today.day == value,
                                muted:
                                    _frequency == _IncomeFrequency.monthly &&
                                    _selected.isNotEmpty &&
                                    !_selected.contains(value),
                                centered: _frequency == _IncomeFrequency.weekly,
                                onTap: () => _selectDay(value),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const AppTodayLegend(),
                          SizedBox(height: sectionSpacing),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Next deposit',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppTokens.textBody,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  nextLabel,
                                  textAlign: TextAlign.right,
                                  style: AppTypography.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_frequency != null) ...[
                          SizedBox(height: sectionSpacing),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                              vertical: AppSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  heading,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  description,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        SizedBox(height: sectionSpacing),
                        AppButton(
                          label: 'Continue',
                          onPressed: complete ? _continue : null,
                          variant: complete
                              ? AppButtonVariant.primary
                              : AppButtonVariant.disabled,
                          disabledBackgroundColor: AppTokens.surface,
                          labelStyle: AppButtonLabelStyle.regular,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 주기 선택지는 선택 여부와 관계없이 같은 글자 크기를 유지한다.
  Widget _frequencyTile(int index) => Material(
    color: _frequency == _IncomeFrequency.values[index]
        ? AppTokens.brandLime
        : AppTokens.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      key: ValueKey('income-frequency-$index'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => _selectFrequency(_IncomeFrequency.values[index]),
      child: SizedBox(
        height: 52,
        child: Center(
          child: Text(
            _labels[index],
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
