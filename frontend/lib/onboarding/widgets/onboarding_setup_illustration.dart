import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 07 화면의 카드와 달력 일러스트를 피그마 배치대로 표시한다.
class OnboardingSetupIllustration extends StatelessWidget {
  const OnboardingSetupIllustration({super.key});

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: SizedBox(
      key: const Key('onboarding-setup-illustration'),
      width: 370,
      height: 300,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 24,
            top: 49,
            width: 207.8,
            height: 189.244,
            child: Center(
              child: Transform.rotate(
                angle: 4 * math.pi / 180,
                child: const _CalendarArt(),
              ),
            ),
          ),
          Positioned(
            left: 190,
            top: 33.95,
            width: 164.391,
            height: 120.589,
            child: Center(
              child: Transform.rotate(
                angle: -10 * math.pi / 180,
                child: const _CardArt(
                  color: AppTokens.brandPurple,
                  chipColor: AppTokens.background,
                ),
              ),
            ),
          ),
          Positioned(
            left: 161.97,
            top: 150,
            width: 159.213,
            height: 111.153,
            child: Center(
              child: Transform.rotate(
                angle: 6 * math.pi / 180,
                child: const _CardArt(
                  color: AppTokens.brandLime,
                  chipColor: AppTokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 공통 월 달력과 구별되는 장식용 날짜 점을 배치한다.
class _CalendarArt extends StatelessWidget {
  const _CalendarArt();

  @override
  Widget build(BuildContext context) => Container(
    width: 196,
    height: 176,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 18,
          top: 16,
          child: Text(
            'August',
            style: AppTypography.caption.copyWith(color: AppTokens.textAccent),
          ),
        ),
        for (var row = 0; row < 4; row++)
          for (var column = 0; column < 7; column++)
            Positioned(
              left:
                  18.0 +
                  24 * column -
                  ((row == 0 && column == 4) || (row == 2 && column == 0)
                      ? 5
                      : 0),
              top:
                  46.0 +
                  30 * row -
                  ((row == 0 && column == 4) || (row == 2 && column == 0)
                      ? 5
                      : 0),
              child: SvgPicture.asset(
                row == 0 && column == 4
                    ? 'assets/onboarding/intro_dot_lime.svg'
                    : row == 2 && column == 0
                    ? 'assets/onboarding/intro_dot_purple.svg'
                    : 'assets/onboarding/intro_dot_white.svg',
              ),
            ),
      ],
    ),
  );
}

/// 색상이 다른 두 카드에 같은 크기와 칩 배치를 적용한다.
class _CardArt extends StatelessWidget {
  const _CardArt({required this.color, required this.chipColor});

  final Color color;
  final Color chipColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    height: 96,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 16,
          top: 20,
          child: Container(
            width: 26,
            height: 18,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
  );
}
