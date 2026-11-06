import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'widgets/onboarding_actions.dart';
import 'widgets/onboarding_setup_illustration.dart';

/// 카드 캘린더 설정 전에 필요한 내용을 소개한다.
class OnboardingSetupIntroPage extends StatelessWidget {
  const OnboardingSetupIntroPage({super.key});

  /// 카드 선택 단계로 이동한다.
  void _startSetup(BuildContext context) => context.goNamed('onboarding-cards');

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  AppSpacing.twoXL,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    const OnboardingSetupIllustration(),
                    const SizedBox(height: AppSpacing.twoXL),
                    Text(
                      'Set up your card calendar\nin a minute',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "We'll mark your closing dates and paydays,\nso you see your bill coming before it lands.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.twoXL),
                    OnboardingActions(
                      label: "Let's go",
                      onPressed: () => _startSetup(context),
                      buttonKey: const Key('onboarding-setup-continue'),
                      secondaryLabel: "I'll do it later",
                      onSecondaryPressed: () => context.goNamed('home'),
                      secondaryKey: const Key('onboarding-setup-skip'),
                    ),
                    const SizedBox(height: AppSpacing.twoXL),
                    Text(
                      'By continuing, you agree to the Terms and Privacy Policy',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textSecondary,
                      ),
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
