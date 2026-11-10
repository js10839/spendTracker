import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components.dart';
import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 사용자가 직접 카드 이름을 입력하는 시트다.
class OnboardingCustomCardSheet extends StatefulWidget {
  const OnboardingCustomCardSheet({super.key});

  @override
  State<OnboardingCustomCardSheet> createState() => _OnboardingCustomCardSheetState();
}

class _OnboardingCustomCardSheetState extends State<OnboardingCustomCardSheet> {
  final _name = TextEditingController();
  final _letters = FilteringTextInputFormatter.allow(RegExp(r'[\p{L}\p{M} ]', unicode: true));

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// 공백을 제거한 카드 이름을 선택 화면에 전달한다.
  void _addCard() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppTokens.background, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          bottom: keyboard == 0,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 10, AppSpacing.xl, AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppTokens.borderSubtle, borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Add another card', style: AppTypography.heading2),
                  const SizedBox(height: 6),
                  Text('Just the name, like how it shows on your statement.', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary)),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Card name', style: AppTypography.bodyMediumStrong),
                  const SizedBox(height: AppSpacing.sm),
                  AppInput(
                    key: const Key('onboarding-custom-card-name'),
                    controller: _name,
                    hintText: '',
                    inputStyle: AppInputStyle.cardName,
                    inputFormatters: [_letters],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.twoXL),
                  AppButton(label: 'Add card', onPressed: _name.text.trim().isEmpty ? null : _addCard, variant: _name.text.trim().isEmpty ? AppButtonVariant.disabled : AppButtonVariant.primary),
                  const SizedBox(height: 10),
                  AppButton(label: 'Cancel', variant: AppButtonVariant.surface, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
