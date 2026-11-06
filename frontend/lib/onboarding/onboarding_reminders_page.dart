import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'onboarding_summary.dart';
import 'widgets/onboarding_actions.dart';
import 'widgets/onboarding_video.dart';

/// 카드 마감 알림의 예시와 권한 선택을 보여준다.
class OnboardingRemindersPage extends StatelessWidget {
  const OnboardingRemindersPage({super.key, required this.summary});
  final OnboardingSummary summary;

  /// 알림 권한 설정이 추가되면 권한 요청 결과를 처리한다.
  void _enableReminders(BuildContext context) {
    // TODO: 실제 알림 권한 요청과 사용자 선택 저장을 연결한다.
    _continue(context);
  }

  /// 설정 화면으로 이동한다.
  void _continue(BuildContext context) =>
      context.goNamed('onboarding-setting-up', extra: summary);

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
                  AppSpacing.fourXL,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Get a heads-up before your cards close',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'One reminder 3 days before each closing date. Nothing else.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.twoXL),
                    const OnboardingVideo(
                      asset: 'assets/onboarding/reminders.mp4',
                      width: 370,
                      height: 280,
                      loop: true,
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.twoXL),
                    OnboardingActions(
                      label: 'Turn on reminders',
                      onPressed: () => _enableReminders(context),
                      secondaryLabel: 'Not now',
                      onSecondaryPressed: () => _continue(context),
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
