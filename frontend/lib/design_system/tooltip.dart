import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';
import 'typography.dart';

/// 강조할 요소 위에 짧은 안내 문구를 말풍선으로 표시한다.
class AppCalloutTooltip extends StatelessWidget {
  const AppCalloutTooltip({super.key, required this.message});

  final String message;

  @override
  /// 안내 문구 아래에 원본 꼬리 SVG를 배치한다.
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTokens.background,
            border: Border.all(color: AppTokens.borderSubtle),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppComponentColors.shadowNeutral.withValues(
                  alpha: 30 / 255,
                ),
                offset: const Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(message, style: AppTypography.bodyMediumStrong),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -1),
          child: SvgPicture.asset('assets/home/imgPointer.svg'),
        ),
      ],
    ),
  );
}
