import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'closing_cycle.dart';
import 'onboarding_summary.dart';
import 'widgets/onboarding_video.dart';

/// 선택한 설정의 임시 준비 화면을 표시한다.
class OnboardingSettingUpPage extends StatelessWidget {
  const OnboardingSettingUpPage({super.key, required this.summary});
  final OnboardingSummary summary;

  /// 임시 영상이 끝나면 완료 화면으로 이동한다.
  void _onVideoComplete(BuildContext context) {
    // TODO: 임시 영상 재생 시간을 실제 설정 저장 완료 시점으로 교체한다.
    context.goNamed('onboarding-ready');
  }

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
                  6,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    OnboardingVideo(
                      asset: 'assets/onboarding/setting_up.mp4',
                      width: 120,
                      height: 120,
                      cropTop: true,
                      onComplete: () => _onVideoComplete(context),
                    ),
                    const SizedBox(height: AppSpacing.twoXL),
                    Text(
                      'Setting up your card calendar…',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading2,
                    ),
                    const SizedBox(height: AppSpacing.twoXL),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppTokens.background,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in summary.cards.entries) ...[
                            _summaryRow(
                              '${entry.key} · closes on the ${ordinalDay(entry.value)}',
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (summary.income != null)
                            _summaryRow(summary.income!),
                        ],
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

  /// 사용자 선택 항목을 설정 요약에 표시한다.
  Widget _summaryRow(String label) => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTokens.borderStrong, width: 1.5),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(
          label,
          style: AppTypography.bodyLarge.copyWith(
            color: AppTokens.textSecondary,
          ),
        ),
      ),
    ],
  );
}
