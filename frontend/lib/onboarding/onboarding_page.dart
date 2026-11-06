import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'widgets/onboarding_actions.dart';
import 'widgets/onboarding_illustrations.dart';

/// 로그인 또는 회원가입 전에 앱 사용법을 소개한다.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _page = 0;

  /// 튜토리얼 페이지를 전환한다.
  void _showPage(int page) {
    // TODO: 화면 전환 모션이 확정되면 이 위치에 적용한다.
    setState(() => _page = page);
  }

  /// 온보딩 소개를 마치고 카드 캘린더 설정 안내로 이동한다.
  void _openSetupIntro() {
    // TODO: 화면 간 전환 모션이 확정되면 이 경로에 적용한다.
    context.goNamed('onboarding-setup');
  }

  /// 기존 회원의 이메일 인증을 시작한다.
  void _openLogin() => context.pushNamed('login-email');

  @override
  /// 안전 영역에 맞춰 온보딩의 공통 레이아웃을 표시한다.
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
                  10,
                ),
                child: _page == 0 ? _welcome() : _tutorial(),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// GIF와 소개 문구가 있는 첫 화면을 표시한다.
  Widget _welcome() => Column(
    children: [
      const SizedBox(height: 30),
      Text(
        'Know your card bill',
        textAlign: TextAlign.center,
        style: AppTypography.displayNumber,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'before it closes',
        textAlign: TextAlign.center,
        style: AppTypography.displayNumber,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'SPENDING, BY STATEMENT CYCLE',
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(color: AppTokens.textAccent),
      ),
      const SizedBox(height: AppSpacing.sm),
      const OnboardingWelcomeIllustration(),
      const SizedBox(height: AppSpacing.sm),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 348),
        child: Text(
          'See what each card will charge you before the statement closes and snap receipts to log every item.',
          textAlign: TextAlign.center,
          style: AppTypography.heading3.copyWith(color: AppTokens.textBody),
        ),
      ),
      const Spacer(),
      const SizedBox(height: 14),
      OnboardingActions(label: 'Continue', onPressed: () => _showPage(1)),
    ],
  );

  /// 세 단계에 공통인 진행 표시와 설명, 버튼을 배치한다.
  Widget _tutorial() {
    final title = [
      'Your card, your cycle',
      'Snap, and it’s sorted',
      'Add your first card',
    ][_page - 1];
    final eyebrow = [
      'NO CARD NUMBER NEEDED',
      'AI SPLITS EVERY RECEIPT',
      'JUST A NAME AND A CLOSING DATE',
    ][_page - 1];
    final description = [
      'Your credit card’s billing cycle\ndoesn’t always align with the calendar month.\nTell us that date and we’ll track each card’s cycle for you.',
      'Take a photo of any receipt -\nwe’ll sort the items into categories automatically.\nYou just review and save.',
      'We never ask for card numbers or bank logins.\nPick a color, set the closing date,\nand your cycle starts tracking right away.',
    ][_page - 1];
    final emphasis = [
      'Just a card name and a closing date.',
      'Every item gets its own category.',
      'Two minutes, and you’ll see your next bill.',
    ][_page - 1];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              AppBackButton(onPressed: () => _showPage(_page - 1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_page / 3',
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppProgress(step: _page),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const SizedBox(width: 36),
            ],
          ),
        ),
        SizedBox(height: _page == 1 ? 45 : 40),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.displayNumber,
        ),
        const SizedBox(height: 6),
        Text(
          eyebrow,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppTokens.textAccent),
        ),
        SizedBox(height: _page == 1 ? 19 : 14),
        OnboardingIllustration(page: _page),
        SizedBox(height: _page == 1 ? 19 : 14),
        if (_page == 1) ...[
          const SizedBox(height: 134),
          const SizedBox(height: 19),
        ],
        Text(
          description,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: AppTokens.textBody),
        ),
        const SizedBox(height: 10),
        Text(
          emphasis,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium,
        ),
        const Spacer(),
        const SizedBox(height: 14),
        OnboardingActions(
          buttonKey: ValueKey('onboarding-continue-$_page'),
          label: 'Continue',
          onPressed: _page == 3 ? _openLogin : () => _showPage(_page + 1),
          secondaryKey: const Key('onboarding-skip'),
          onSecondaryPressed: _page == 3 ? _openSetupIntro : () => _showPage(3),
          secondaryLabel: _page == 3 ? 'Continue without login' : 'Skip',
        ),
      ],
    );
  }
}
