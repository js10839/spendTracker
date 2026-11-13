import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../design_system/components.dart';
import '../auth/auth_service.dart';
import '../auth/member_bootstrap.dart';
import '../data/users/user_repository.dart';
import 'widgets/onboarding_animation.dart';

/// 온보딩 완료 애니메이션을 보여주고 홈으로 이동한다.
class OnboardingReadyPage extends StatefulWidget {
  const OnboardingReadyPage({super.key});

  @override
  State<OnboardingReadyPage> createState() => _OnboardingReadyPageState();
}

class _OnboardingReadyPageState extends State<OnboardingReadyPage> {
  bool _loading = false;
  bool _failed = false;
  bool _started = false;

  /// 회원의 현재 세션을 확인하고 초기화한 뒤 홈으로 이동한다.
  Future<void> _continue() async {
    if (_loading) return;
    setState(() { _loading = true; _failed = false; });
    try {
      final auth = AuthService.instance;
      if (auth.currentUserId == null) {
        if (mounted) context.goNamed('home', extra: const GuestHomeAccess());
        return;
      }
      if (!await auth.hasUsableSession()) {
        if (mounted) context.goNamed('login-email');
        return;
      }
      final access = await MemberBootstrap(auth, UserRepository.instance).run();
      if (!mounted) return;
      if (access == null) {
        context.goNamed('login-email');
      } else {
        context.goNamed(access.onboardingRequired ? 'signup' : 'home', extra: access);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 완료 애니메이션에서 화면 이동을 한 번만 시작한다.
  void _onAnimationComplete() {
    if (_started) return;
    _started = true;
    _continue();
  }

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
                    OnboardingAnimation(
                      asset: 'assets/onboarding/ready-check.gif',
                      width: 200,
                      height: 200,
                      lastFrame: 95,
                      finalFrameDuration: const Duration(milliseconds: 20),
                      onComplete: _onAnimationComplete,
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
                    if (_failed) ...[
                      const SizedBox(height: AppSpacing.twoXL),
                      // TODO: 초기화 실패 및 재시도 UI를 확정된 디자인으로 교체한다.
                      Text('Unable to start. Please try again.', textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: AppTokens.statusDanger)),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(label: 'Try again', onPressed: _loading ? null : _continue),
                    ],
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
