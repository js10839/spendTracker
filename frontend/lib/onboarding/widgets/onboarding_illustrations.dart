import 'package:flutter/material.dart';

import 'onboarding_animation.dart';

/// 환영 화면에서 제공된 원본 캘린더 GIF를 재생한다.
class OnboardingWelcomeIllustration extends StatelessWidget {
  const OnboardingWelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 336),
    child: AspectRatio(
      aspectRatio: 1,
      child: Image.asset(
        'assets/onboarding/calendar_flip.gif',
        fit: BoxFit.contain,
      ),
    ),
  );
}

/// 단계별 원본 GIF를 기존 일러스트 영역에 표시한다.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => switch (page) {
    1 => const OnboardingAnimation(asset: 'assets/onboarding/cycle-arc.gif', width: 370, height: 224),
    2 => const OnboardingAnimation(asset: 'assets/onboarding/receipt-sort.gif', width: 370, height: 362),
    _ => const OnboardingAnimation(asset: 'assets/onboarding/cards-pop.gif', width: 370, height: 362),
  };
}
