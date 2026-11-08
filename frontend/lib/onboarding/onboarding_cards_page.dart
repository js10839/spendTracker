import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'widgets/onboarding_custom_card_sheet.dart';

/// 설정할 카드사를 최대 두 개까지 선택한다.
class OnboardingCardsPage extends StatefulWidget {
  const OnboardingCardsPage({super.key});

  @override
  State<OnboardingCardsPage> createState() => _OnboardingCardsPageState();
}

class _OnboardingCardsPageState extends State<OnboardingCardsPage> {
  static const _cards = [
    'Chase',
    'Amex',
    'Capital One',
    'Citi',
    'Discover',
    'Apple Card',
    'Bank of America',
    'Wells Fargo',
  ];
  final _customCards = <String>[];
  final _selectedCards = <String>[];
  int _progressStart = 0;
  int _progressVersion = 0;

  /// 선택을 토글하고 세 번째 카드는 가장 오래된 선택을 대체한다.
  void _toggleCard(String card) {
    setState(() {
      if (_selectedCards.contains(card)) {
        _selectedCards.remove(card);
      } else {
        if (_selectedCards.length == 2) _selectedCards.removeAt(0);
        _selectedCards.add(card);
      }
    });
  }

  /// 직접 입력한 이름을 목록에 추가하거나 기존 항목을 선택한다.
  Future<void> _addCustomCard() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppComponentColors.onboardingSheetOverlay.withValues(alpha: 114 / 255),
      builder: (_) => const OnboardingCustomCardSheet(),
    );
    if (!mounted || name == null) return;
    setState(() {
      final matches = [..._cards, ..._customCards].where((card) => card.toLowerCase() == name.toLowerCase());
      final card = matches.isEmpty ? name : matches.first;
      if (matches.isEmpty) _customCards.add(card);
      if (!_selectedCards.contains(card)) {
        if (_selectedCards.length == 2) _selectedCards.removeAt(0);
        _selectedCards.add(card);
      }
    });
  }

  /// 다음 카드 설정 화면이 준비될 때 선택 목록을 전달한다.
  Future<void> _continue() async {
    await context.pushNamed('onboarding-closing', extra: List<String>.of(_selectedCards));
    if (mounted) setState(() { _progressStart = 3; _progressVersion++; });
  }

  /// 카드 설정을 건너뛰고 수입 주기를 선택한다.
  Future<void> _skip() async {
    await context.pushNamed('onboarding-income', extra: 2);
    if (mounted) setState(() { _progressStart = 4; _progressVersion++; });
  }

  @override
  Widget build(BuildContext context) {
    final count = _selectedCards.length;
    final cards = [..._cards, ..._customCards, 'Other'];
    return Scaffold(
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
                          AppBackButton(
                            onPressed: () =>
                                context.goNamed('onboarding-setup'),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AppProgress(
                              key: ValueKey(_progressVersion),
                              step: 2,
                              totalSteps: 5,
                              initialStep: _progressStart,
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
                      const SizedBox(height: AppSpacing.twoXL),
                      Text(
                        'Which credit cards do you\nhave?',
                        textAlign: TextAlign.center,
                        style: AppTypography.heading1,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No card number needed. Just the name.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.twoXL),
                      Text(
                        'Popular picks',
                        style: AppTypography.caption.copyWith(
                          color: AppTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < cards.length; i += 2) ...[
                        Row(
                          children: [
                            Expanded(
                              child: AppOption(
                                key: i == cards.length - 1 ? const ValueKey('onboarding-other') : ValueKey(cards[i]),
                                label: cards[i],
                                selected: i != cards.length - 1 && _selectedCards.contains(cards[i]),
                                onTap: i == cards.length - 1 ? _addCustomCard : () => _toggleCard(cards[i]),
                                style: AppOptionStyle.onboardingCard,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: i + 1 < cards.length
                                  ? AppOption(
                                      key: i + 1 == cards.length - 1 ? const ValueKey('onboarding-other') : ValueKey(cards[i + 1]),
                                      label: cards[i + 1],
                                      selected: i + 1 != cards.length - 1 && _selectedCards.contains(
                                        cards[i + 1],
                                      ),
                                      onTap: i + 1 == cards.length - 1 ? _addCustomCard : () => _toggleCard(cards[i + 1]),
                                      style: AppOptionStyle.onboardingCard,
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                        if (i + 2 < cards.length) const SizedBox(height: 10),
                      ],
                      const Spacer(),
                      const SizedBox(height: AppSpacing.twoXL),
                      AppButton(
                        key: const Key('onboarding-cards-continue'),
                        label:
                            'Continue · $count ${count == 1 ? 'card' : 'cards'}',
                        onPressed: count == 0 ? null : _continue,
                        variant: count == 0
                            ? AppButtonVariant.disabled
                            : AppButtonVariant.primary,
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
    );
  }
}
