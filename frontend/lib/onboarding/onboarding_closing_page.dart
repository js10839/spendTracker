import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/closing_day_picker.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'closing_cycle.dart';
import 'onboarding_summary.dart';

/// 선택한 카드별 명세서 마감일을 설정한다.
class OnboardingClosingPage extends StatefulWidget {
  const OnboardingClosingPage({super.key, required this.cards});
  final List<String> cards;

  @override
  State<OnboardingClosingPage> createState() => _OnboardingClosingPageState();
}

class _OnboardingClosingPageState extends State<OnboardingClosingPage> {
  final _days = <String, int>{};
  var _index = 0;
  var _progressStart = 2;
  var _progressVersion = 0;

  /// 설정을 버리고 카드 선택 화면으로 돌아간다.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('onboarding-cards');
    }
  }

  /// 설정되지 않은 카드로 이동하거나 다음 단계 연결을 기다린다.
  Future<void> _next() async {
    final missing = widget.cards.indexWhere((card) => !_days.containsKey(card));
    if (missing >= 0) {
      setState(() => _index = missing);
    } else {
      await context.pushNamed('onboarding-reminders', extra: OnboardingSummary(cards: Map<String, int>.of(_days)));
      if (mounted) setState(() { _progressStart = 4; _progressVersion++; });
    }
  }

  /// 입력을 초기화하고 다음 단계 연결을 기다린다.
  Future<void> _skip() async {
    setState(_days.clear);
    await context.pushNamed('onboarding-reminders', extra: const OnboardingSummary());
    if (mounted) setState(() { _progressStart = 4; _progressVersion++; });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        body: Center(child: AppBackButton(onPressed: _back)),
      );
    }
    final card = widget.cards[_index];
    final selectedDay = _days[card];
    final missing = widget.cards.indexWhere((item) => item != card && !_days.containsKey(item));
    final nextCard = missing >= 0 ? widget.cards[missing] : null;
    final handled = _days.containsKey(card);
    final today = DateTime.now();
    final cycle = selectedDay == null ? null : closingCycle(today, selectedDay);
    final daysLeft = cycle == null
        ? null
        : DateTime.utc(
            cycle.end.year,
            cycle.end.month,
            cycle.end.day,
          ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
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
                                key: ValueKey(_progressVersion),
                                step: 3,
                                totalSteps: 5,
                                initialStep: _progressStart,
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
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
                        const SizedBox(height: 14),
                        Text(
                          'When does your $card statement close?',
                          textAlign: TextAlign.center,
                          style: AppTypography.heading1,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Look for "Closing Date" on your statement. \nNot the due date.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            for (var i = 0; i < widget.cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: _cardTab(i)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppClosingDayPicker(
                          selectedDay: selectedDay,
                          today: today,
                          onSelected: (day) => setState(() {
                            if (day == null) {
                              _days.remove(card);
                            } else {
                              _days[card] = day;
                            }
                          }),
                        ),
                        const SizedBox(height: 14),
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
                                cycle == null
                                    ? 'Pick your closing date'
                                    : '${ordinalDay(cycle.start.day)} – ${ordinalDay(cycle.end.day)}, every month',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                cycle == null
                                    ? "We'll split your spending by this cycle."
                                    : daysLeft == 0
                                    ? 'Closes today'
                                    : 'Closes in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppButton(
                          label: nextCard == null
                              ? 'Continue'
                              : 'Next: $nextCard closing date',
                          onPressed: handled ? _next : null,
                          variant: !handled
                              ? AppButtonVariant.disabled
                              : AppButtonVariant.primary,
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

  /// 카드 탭은 선택 여부와 무관하게 같은 글자 크기를 사용한다.
  Widget _cardTab(int index) => Material(
    color: index == _index ? AppTokens.brandLime : AppTokens.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      key: ValueKey('closing-card-${widget.cards[index]}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      onTap: () => setState(() => _index = index),
      child: SizedBox(
        height: 52,
        child: Center(
          child: Text(
            widget.cards[index],
            style: AppTypography.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );
}
