/// 온보딩에서 선택한 카드와 수입 주기를 다음 화면에 전달한다.
class OnboardingSummary {
  const OnboardingSummary({this.cards = const {}, this.income});

  final Map<String, int> cards;
  final String? income;
}
