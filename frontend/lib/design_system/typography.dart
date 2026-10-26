import 'package:flutter/material.dart';

import 'tokens.dart';

/// Figma Typography 섹션의 텍스트 스타일 12개를 공유한다.
abstract final class AppTypography {
  static const fontFamily = 'Outfit';

  // 금액 표시에 사용한다.
  static final displayAmount = _style(40, FontWeight.w700, 1.2);

  // 화면 제목과 본문에 사용한다.
  static final heading1 = _style(28, FontWeight.w700, 1.3);
  static final heading2 = _style(22, FontWeight.w700, 1.3);
  static final heading3 = _style(18, FontWeight.w600, 1.4);
  static final bodyLarge = _style(16, FontWeight.w400, 1.5);
  static final bodyLargeStrong = _style(16, FontWeight.w600, 1.5);
  static final bodyMedium = _style(14, FontWeight.w400, 1.5);
  static final bodyMediumStrong = _style(14, FontWeight.w600, 1.5);

  // 버튼, 선택지와 보조 정보에 사용한다.
  static final labelButton = _style(16, FontWeight.w600, 1.2);
  static final labelMedium = _style(14, FontWeight.w600, 1.2);
  static final captionEyebrow = _style(12, FontWeight.w700, 1.4, spacing: 0.72);
  static final caption = _style(12, FontWeight.w500, 1.4);

  /// 보내주신 코드의 글꼴, 크기, 굵기, 줄 높이와 자간을 적용한다.
  static TextStyle _style(
    double size,
    FontWeight weight,
    double height, {
    double spacing = 0,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: AppTokens.textPrimary,
  );
}
