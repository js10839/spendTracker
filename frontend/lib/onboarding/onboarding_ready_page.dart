import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'widgets/onboarding_video.dart';

/// 온보딩 완료 애니메이션을 보여주고 홈으로 이동한다.
class OnboardingReadyPage extends StatelessWidget {
  const OnboardingReadyPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTokens.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth, minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  6,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    OnboardingVideo(
                      asset: 'assets/onboarding/lets_start.mp4',
                      width: 200,
                      height: 200,
                      onComplete: () => context.goNamed('home'),
                    ),
                    const SizedBox(height: AppSpacing.threeXL),
                    Text(
                      'Let’s start!',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your card calendar is ready.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
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
