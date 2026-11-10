import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import 'onboarding_summary.dart';
import 'widgets/onboarding_animation.dart';

/// 제공된 예시 애니메이션을 재생한 뒤 완료 화면으로 이동한다.
class OnboardingSettingUpPage extends StatelessWidget {
  const OnboardingSettingUpPage({super.key, required this.summary});
  final OnboardingSummary summary;

  /// 실제 설정 저장이 연결되기 전에는 GIF 재생 후 진행한다.
  void _onAnimationComplete(BuildContext context) {
    // TODO: 실제 설정 저장 완료 시점을 기다리고 선택한 설정을 표시한다.
    context.goNamed('onboarding-ready');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTokens.background,
    body: SafeArea(
      child: Center(
        child: OnboardingAnimation(
          asset: 'assets/onboarding/setup.gif',
          width: 370,
          height: 481,
          lastFrame: 119,
          onComplete: () => _onAnimationComplete(context),
        ),
      ),
    ),
  );
}
