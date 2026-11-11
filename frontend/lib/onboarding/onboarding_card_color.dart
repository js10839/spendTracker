import '../design_system/tokens.dart';

/// 온보딩 카드사의 기본 색상을 공통 색상 토큰에서 선택한다.
String onboardingCardColor(String name) {
  final color = switch (name) {
    'Chase' || 'Amex' || 'Capital One' || 'Citi' => AppPalette.accentBlue,
    'Discover' => AppPalette.accentOrange,
    'Apple Card' => AppPalette.neutral100,
    'Bank of America' || 'Wells Fargo' => AppPalette.accentRed,
    _ => AppPalette.neutral200,
  };
  return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
