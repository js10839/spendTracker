import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../data/payment_methods/payment_method_repository.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'closing_cycle.dart';
import 'onboarding_card_color.dart';
import 'onboarding_summary.dart';
import 'widgets/onboarding_animation.dart';

/// 설정 저장과 애니메이션이 완료되면 다음 화면으로 이동한다.
class OnboardingSettingUpPage extends StatefulWidget {
  const OnboardingSettingUpPage({super.key, required this.summary});
  final OnboardingSummary summary;

  @override
  State<OnboardingSettingUpPage> createState() => _OnboardingSettingUpPageState();
}

class _OnboardingSettingUpPageState extends State<OnboardingSettingUpPage> {
  final _saved = <String>{};
  bool _saving = false;
  bool _failed = false;
  bool _finishedSaving = false;
  bool _finishedAnimation = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _finishedAnimation = widget.summary.cards.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _saveCards();
    });
  }

  /// 현재 화면에서 저장에 성공한 카드는 재요청하지 않는다.
  Future<void> _saveCards() async {
    if (_saving) return;
    setState(() { _saving = true; _failed = false; });
    try {
      final auth = AuthService.instance;
      final userId = auth.currentUserId;
      // TODO: 게스트 카드 설정은 로컬 SQLite 저장소가 연결되면 저장한다.
      if (userId != null && widget.summary.cards.isNotEmpty) {
        if (!await auth.hasUsableSession() || auth.currentUserId != userId) throw StateError('Session unavailable');
        for (final card in widget.summary.cards.entries) {
          if (_saved.contains(card.key)) continue;
          if (auth.currentUserId != userId) throw StateError('Session changed');
          // TODO: 앱 종료나 응답 유실 후 중복 방지는 백엔드와 함께 지원한다.
          await PaymentMethodRepository.instance.createCreditCard(name: card.key, closingDay: card.value, color: onboardingCardColor(card.key));
          if (!mounted) return;
          setState(() => _saved.add(card.key));
        }
      }
      if (mounted) setState(() => _finishedSaving = true);
      _navigateWhenReady();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 카드가 있으면 GIF 한 사이클과 저장을 기다린 뒤 이동한다.
  void _navigateWhenReady() {
    if (!mounted || !_finishedSaving || !_finishedAnimation || _navigated) return;
    _navigated = true;
    context.goNamed('onboarding-ready');
  }

  /// 애니메이션 완료를 기록하고 저장 완료 여부를 확인한다.
  void _onAnimationComplete() {
    _finishedAnimation = true;
    _navigateWhenReady();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTokens.background,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 원본 GIF의 고정 카드·급여 예시를 가리고 애니메이션과 제목만 표시한다.
          ClipRect(child: Align(alignment: Alignment.topCenter, heightFactor: 0.65, child: OnboardingAnimation(asset: 'assets/onboarding/setup.gif', width: 370, height: 481, lastFrame: 119, onComplete: _onAnimationComplete))),
          Container(width: double.infinity, padding: const EdgeInsets.all(AppSpacing.xl), decoration: BoxDecoration(color: AppTokens.background, borderRadius: BorderRadius.circular(AppRadius.lg)), child: Column(children: [
            for (final card in widget.summary.cards.entries) ...[
              if (card.key != widget.summary.cards.keys.first) const SizedBox(height: 14),
              Row(children: [
                Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: _saved.contains(card.key) ? AppTokens.brandLime : AppTokens.background, border: _saved.contains(card.key) ? null : Border.all(color: AppTokens.borderStrong, width: 1.5)), child: _saved.contains(card.key) ? const Icon(Icons.check, size: 16, color: AppTokens.textPrimary) : null),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('${card.key} · closes on the ${ordinalDay(card.value)}', style: AppTypography.bodyLarge)),
              ]),
            ],
          ])),
          if (_failed) Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Column(children: [
            // TODO: 저장 오류 화면은 확정된 디자인으로 교체한다.
            Text('Unable to save your cards. Please try again.', textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: AppTokens.statusDanger)),
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: 'Try again', onPressed: _saving ? null : _saveCards),
          ])),
        ])),
      ),
    ),
  );
}
