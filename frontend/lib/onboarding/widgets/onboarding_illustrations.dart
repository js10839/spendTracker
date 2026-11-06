import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 환영 화면에서 제공된 원본 캘린더 GIF를 재생한다.
class OnboardingWelcomeIllustration extends StatelessWidget {
  const OnboardingWelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 336),
    child: AspectRatio(
      aspectRatio: 1,
      child: Image.asset(
        'assets/onboarding/onboarding_motion.gif',
        fit: BoxFit.contain,
      ),
    ),
  );
}

/// 각 단계의 정적인 피그마 일러스트를 표시한다.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    // TODO: 단계별 일러스트 모션이 확정되면 이 위치에 적용한다.
    return switch (page) {
      1 => const _CycleIllustration(),
      2 => const _ReceiptIllustration(),
      _ => const _CardIllustration(),
    };
  }
}

/// 결제 주기 곡선과 시작일, 누적 금액, 마감일을 표시한다.
class _CycleIllustration extends StatelessWidget {
  const _CycleIllustration();

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      width: 370,
      height: 224,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            SvgPicture.asset('assets/onboarding/cycle_arc.svg'),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aug 6\nstart',
                  style: AppTypography.caption.copyWith(
                    color: AppTokens.textSecondary,
                  ),
                ),
                Column(
                  children: [
                    Text('\$482.30', style: AppTypography.heading3),
                    Text(
                      'so far',
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Sep 5\ncloses',
                  textAlign: TextAlign.right,
                  style: AppTypography.caption.copyWith(
                    color: AppTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 영수증과 분류된 품목의 정적인 배치를 보여준다.
class _ReceiptIllustration extends StatelessWidget {
  const _ReceiptIllustration();

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      width: 370,
      height: 362,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 22,
            top: 62.69,
            width: 104.876,
            height: 136.915,
            child: Center(
              child: Transform.rotate(
                angle: -6 * math.pi / 180,
                child: const _Receipt(),
              ),
            ),
          ),
          Positioned(
            left: 130,
            top: 32,
            width: 185.764,
            height: 78.526,
            child: Center(
              child: Transform.rotate(
                angle: -8 * math.pi / 180,
                child: _IllustrationPill(
                  label: 'Apples · Food',
                  color: AppTokens.brandLime,
                  icon: SvgPicture.asset('assets/onboarding/receipt_food.svg'),
                ),
              ),
            ),
          ),
          Positioned(
            left: 134.36,
            top: 124.3,
            width: 214.494,
            height: 75.655,
            child: Center(
              child: Transform.rotate(
                angle: 6 * math.pi / 180,
                child: const _IllustrationPill(
                  label: 'Dish soap · Living',
                  color: AppTokens.brandPurple,
                  inverse: true,
                  icon: _LivingIcon(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 128,
            top: 177.59,
            width: 205.275,
            height: 67.959,
            child: Center(
              child: Transform.rotate(
                angle: -4 * math.pi / 180,
                child: _IllustrationPill(
                  label: 'T-shirt · Fashion',
                  color: AppTokens.surface,
                  icon: SvgPicture.asset(
                    'assets/onboarding/receipt_fashion.svg',
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 140.62,
            top: 244.3,
            width: 193.536,
            height: 85.652,
            child: Center(
              child: Transform.rotate(
                angle: 10 * math.pi / 180,
                child: _IllustrationPill(
                  label: 'Tax · Tax & Tip',
                  color: AppTokens.background,
                  outlined: true,
                  icon: SvgPicture.asset('assets/onboarding/receipt_tax.svg'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 첫 카드 소개에 표시되는 결제수단 예시를 배치한다.
class _CardIllustration extends StatelessWidget {
  const _CardIllustration();

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      width: 370,
      height: 250,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 10.94,
            top: 30,
            width: 142.113,
            height: 84.572,
            child: Center(
              child: Transform.rotate(
                angle: 14 * math.pi / 180,
                child: const _IllustrationPill(
                  label: 'Chase',
                  color: AppTokens.background,
                  outlined: true,
                  card: true,
                  icon: _CardMark(letter: 'C', color: AppPalette.accentBlue),
                ),
              ),
            ),
          ),
          Positioned(
            left: 170,
            top: 43.95,
            width: 135.432,
            height: 75.407,
            child: Center(
              child: Transform.rotate(
                angle: -10 * math.pi / 180,
                child: const _IllustrationPill(
                  label: 'Amex',
                  color: AppTokens.brandPurple,
                  inverse: true,
                  card: true,
                  icon: _CardMark(letter: 'A', color: AppPalette.accentSky),
                ),
              ),
            ),
          ),
          Positioned(
            left: 36.23,
            top: 150,
            width: 126.467,
            height: 62.449,
            child: Center(
              child: Transform.rotate(
                angle: 4 * math.pi / 180,
                child: _IllustrationPill(
                  label: 'Cash',
                  color: AppTokens.background,
                  outlined: true,
                  card: true,
                  icon: SvgPicture.asset('assets/onboarding/card_cash.svg'),
                ),
              ),
            ),
          ),
          Positioned(
            left: 196,
            top: 112.12,
            width: 179.157,
            height: 109.229,
            child: Center(
              child: Transform.rotate(
                angle: -20 * math.pi / 180,
                child: const _IllustrationPill(
                  label: 'BofA Debit',
                  color: AppTokens.brandLime,
                  card: true,
                  icon: _CardMark(
                    letter: 'B',
                    color: AppPalette.accentPink,
                    chipColor: AppTokens.brandLime,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 각 소개 그림에 반복되는 아이콘과 텍스트 캡슐을 표시한다.
class _IllustrationPill extends StatelessWidget {
  const _IllustrationPill({
    required this.label,
    required this.color,
    required this.icon,
    this.inverse = false,
    this.outlined = false,
    this.card = false,
  });
  final String label;
  final Color color;
  final Widget icon;
  final bool inverse, outlined, card;

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: EdgeInsets.only(left: card ? 12 : 22, right: card ? 20 : 22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(27),
      border: outlined ? Border.all(color: AppTokens.borderSubtle) : null,
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.heading3.copyWith(
              color: inverse ? AppTokens.textInverse : AppTokens.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 영수증의 여섯 줄을 피그마에서 지정한 길이와 색으로 그린다.
class _Receipt extends StatelessWidget {
  const _Receipt();

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    height: 128,
    decoration: BoxDecoration(
      color: AppTokens.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Stack(
      children: [
        for (final (index, width) in const [
          50.0,
          47.0,
          34.0,
          51.0,
          38.0,
          55.0,
        ].indexed)
          Positioned(
            left: 14,
            top: 16 + index * 16,
            child: Container(
              width: width,
              height: 5,
              decoration: BoxDecoration(
                color: index == 0
                    ? AppTokens.textSecondary
                    : AppTokens.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    ),
  );
}

/// 흰색 생활용품 아이콘을 피그마의 세 도형으로 구성한다.
class _LivingIcon extends StatelessWidget {
  const _LivingIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: Stack(
      children: [
        Positioned(
          left: 4.5,
          top: 6,
          child: Container(
            width: 9,
            height: 11.25,
            decoration: BoxDecoration(
              color: AppTokens.textInverse,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          left: 6.75,
          top: 2.25,
          child: Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppTokens.textInverse,
              borderRadius: BorderRadius.circular(1.125),
            ),
          ),
        ),
        Positioned(
          left: 7.875,
          top: 0.375,
          child: Container(
            width: 2.25,
            height: 2.25,
            decoration: BoxDecoration(
              color: AppTokens.textInverse,
              borderRadius: BorderRadius.circular(0.75),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 실제 카드 정보 대신 예시 색상과 이니셜을 표시한다.
class _CardMark extends StatelessWidget {
  const _CardMark({
    required this.letter,
    required this.color,
    this.chipColor = AppTokens.textInverse,
  });
  final String letter;
  final Color color, chipColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 26,
    padding: const EdgeInsets.only(right: 5, bottom: 3),
    alignment: Alignment.bottomRight,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 5,
          top: 5,
          child: Container(
            width: 8,
            height: 6,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            letter,
            style: AppTypography.caption.copyWith(color: AppTokens.textInverse),
          ),
        ),
      ],
    ),
  );
}
