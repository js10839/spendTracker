import 'package:flutter/material.dart';

import '../../design_system/components.dart';
import '../../design_system/tokens.dart';
import '../../design_system/typography.dart';

/// 온보딩의 기본 버튼과 선택적인 하단 링크를 같은 간격으로 표시한다.
class OnboardingActions extends StatelessWidget {
  const OnboardingActions({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.secondaryKey,
  });

  final String label;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppButton(
        key: buttonKey,
        label: label,
        labelStyle: AppButtonLabelStyle.regular,
        onPressed: onPressed,
      ),
      if (secondaryLabel != null) ...[
        const SizedBox(height: 14),
        InkWell(
          key: secondaryKey,
          onTap: onSecondaryPressed,
          child: Text(
            secondaryLabel!,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppTokens.textSecondary,
            ),
          ),
        ),
      ],
    ],
  );
}
