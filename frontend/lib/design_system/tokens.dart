import 'package:flutter/material.dart';

/// Figma Spacing의 xs부터 5xl까지 9단계를 정의한다.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const twoXL = 24.0;
  static const threeXL = 32.0;
  static const fourXL = 40.0;
  static const fiveXL = 48.0;
}

/// Figma Radius의 sm부터 full까지 5단계를 정의한다.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const full = 999.0;
}

/// Figma 화면에 표시된 기본 색상 20개를 보관한다.
abstract final class AppPalette {
  static const lime500 = Color(0xFFCEF370);
  static const lime600 = Color(0xFFB1DD40);
  static const purple500 = Color(0xFF905AFC);
  static const purple600 = Color(0xFF7135E9);
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral100 = Color(0xFFF6F7F6);
  static const neutral200 = Color(0xFFEBEEEC);
  static const neutral300 = Color(0xFFD5DAD7);
  static const neutral400 = Color(0xFFB3BBB6);
  static const neutral500 = Color(0xFF6B7A71);
  static const neutral600 = Color(0xFF4A5B51);
  static const neutral700 = Color(0xFF33443A);
  static const neutral800 = Color(0xFF24342A);
  static const neutral900 = Color(0xFF1B2820);
  static const neutral950 = Color(0xFF141F18);
  static const accentRed = Color(0xFFFC5A5A);
  static const accentOrange = Color(0xFFFCA05A);
  static const accentSky = Color(0xFF5AD4FC);
  static const accentBlue = Color(0xFF5A8BFC);
  static const accentPink = Color(0xFFFC5B9C);
}

/// Figma의 의미별 색상 16개를 기본 색상에 연결한다.
abstract final class AppTokens {
  static const background = AppPalette.neutral0;
  static const surface = AppPalette.neutral100;
  static const overlayDim = Color(0x72131F17);
  static const textPrimary = AppPalette.neutral950;
  static const textBody = AppPalette.neutral700;
  static const textSecondary = AppPalette.neutral500;
  static const textDisabled = AppPalette.neutral400;
  static const textAccent = AppPalette.purple600;
  static const textEyebrow = AppPalette.purple600;
  static const brandLime = AppPalette.lime500;
  static const brandLimePressed = AppPalette.lime600;
  static const brandPurple = AppPalette.purple500;
  static const borderSubtle = AppPalette.neutral200;
  static const borderStrong = AppPalette.neutral300;
  static const statusDanger = AppPalette.accentRed;
  static const statusWarning = AppPalette.accentOrange;
  static const statusInfo = AppPalette.accentSky;

  static const radiusSmall = AppRadius.sm;
  static const radiusMedium = AppRadius.md;
  static const radiusLarge = AppRadius.lg;
  static const radiusXLarge = AppRadius.xl;
}

/// Components 섹션에서 쓰는 추가 의미 색상을 원본 값으로 보관한다.
abstract final class AppComponentColors {
  static const surface = Color(0xFFF1F3F2);
  static const borderSubtle = Color(0xFFDCE1DE);
  static const disabledText = Color(0xFF919C95);
  static const brandSubtle = Color(0xFFF5F0FF);
  static const incomeSubtle = Color(0xFFF4FCDE);
  static const warningSubtle = Color(0xFFFDF1E2);
  static const dangerSubtle = Color(0xFFFDE2E2);
  static const incomeText = Color(0xFF657E25);
  static const dangerText = Color(0xFF9C1C1C);
}
