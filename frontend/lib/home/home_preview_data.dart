import 'package:flutter/material.dart';

import '../design_system/tokens.dart';

typedef HomePreviewTransaction = ({
  int card,
  int cents,
  String merchant,
  int itemCount,
});

typedef HomePreviewItem = ({String name, String category, int cents});

/// 홈 API가 준비될 때까지 Figma 화면의 예시 값을 한곳에서 제공한다.
abstract final class HomePreviewData {
  static const cardNames = ['All', 'Chase', 'Amex', 'Cash', 'BofA'];
  static const cardColors = [
    AppPalette.purple500,
    AppPalette.accentBlue,
    AppPalette.accentSky,
    AppPalette.accentOrange,
    AppPalette.accentPink,
  ];
  static const closingDays = <int?>[null, 5, 15, null, null];
  static const amounts = [81245, 48230, 19415, 8000, 4780];
  // Figma의 수입 예시는 결제수단이 지정되지 않은 전체 수입이다.
  static const incomeRecords = <({int? card, int cents})>[(card: null, cents: 76745)];

  /// 전체 또는 선택한 결제수단에 연결된 예시 수입을 합산한다.
  static int incomeFor(int card) => incomeRecords.where((income) => card == 0 || income.card == card).fold(0, (sum, income) => sum + income.cents);
  static const initialNote = 'Costco run for the party this weekend';
  static const dailyAmounts = <int, int>{
    1: 48,
    2: 15,
    4: 71,
    5: 412,
    6: 24,
    8: 70,
    10: 67,
    12: 32,
    14: 66,
    15: 356,
    16: 62,
    17: 27,
    19: 195,
    20: 5,
    21: 12,
    22: 60,
    23: 18,
    24: 40,
  };
  static final dailyDots = <int, List<Color>>{
    1: [AppPalette.accentSky, AppTokens.brandLime.withValues(alpha: 0.50)],
    2: [AppPalette.accentSky],
    4: [AppPalette.accentBlue, AppPalette.accentSky],
    6: [AppPalette.accentOrange],
    8: [AppPalette.accentBlue, AppPalette.accentOrange, AppPalette.accentSky],
    10: [AppPalette.accentSky, AppTokens.brandLime.withValues(alpha: 0.50)],
    12: [AppPalette.accentSky],
    14: [AppPalette.accentBlue, AppPalette.accentSky],
    16: [AppPalette.accentBlue, AppPalette.accentSky],
    17: [AppPalette.accentSky, AppPalette.accentOrange],
    19: [AppPalette.accentBlue, AppPalette.accentSky, AppPalette.accentPink],
    20: [AppPalette.accentSky],
    21: [AppPalette.accentOrange],
    22: [AppPalette.accentSky],
    23: [AppPalette.accentSky],
    24: [AppPalette.accentBlue, AppPalette.accentSky, AppPalette.accentPink],
  };

  /// 홈 예시 거래를 결제수단별로 나눠 API의 payment_method_id 필터를 흉내 낸다.
  static List<HomePreviewTransaction> transactionsFor(DateTime date) {
    if (date.year != 2026 || date.month != 8) return [];
    if (date.day == 24) {
      return const [
        (card: 1, cents: 2213, merchant: 'Target', itemCount: 4),
        (card: 2, cents: 3907, merchant: 'Sweetgreen', itemCount: 5),
        (card: 4, cents: 2500, merchant: 'Shell', itemCount: 4),
      ];
    }
    final cards = [
      for (var card = 1; card < cardColors.length; card++)
        if (dailyDots[date.day]?.contains(cardColors[card]) ?? false) card,
    ];
    if (cards.isEmpty) return [];
    final cents = (dailyAmounts[date.day] ?? 0) * 100;
    final share = cents ~/ cards.length;
    return [
      for (var index = 0; index < cards.length; index++)
        (
          card: cards[index],
          cents: share + (index == 0 ? cents % cards.length : 0),
          merchant: 'Expense',
          itemCount: 1,
        ),
    ];
  }

  /// 예시 거래의 품목 합계가 가게별 금액과 일치하도록 유지한다.
  static List<HomePreviewItem> itemsFor(HomePreviewTransaction transaction) =>
      switch (transaction.merchant) {
        'Target' => const [
          (name: 'Groceries', category: 'Food', cents: 949),
          (name: 'Home supplies', category: 'Living', cents: 499),
          (name: 'Snacks', category: 'Food', cents: 425),
          (name: 'Tax', category: 'Tax & Tip', cents: 340),
        ],
        'Sweetgreen' => const [
          (name: 'Harvest bowl', category: 'Dining', cents: 1495),
          (name: 'Drink', category: 'Dining', cents: 395),
          (name: 'Side', category: 'Dining', cents: 795),
          (name: 'Cookie', category: 'Dining', cents: 450),
          (name: 'Tax & Tip', category: 'Tax & Tip', cents: 772),
        ],
        'Shell' => const [
          (name: 'Gas', category: 'Transport', cents: 1800),
          (name: 'Car wash', category: 'Transport', cents: 500),
          (name: 'Snack', category: 'Food', cents: 150),
          (name: 'Tax', category: 'Tax & Tip', cents: 50),
        ],
        _ => [
          (
            name: transaction.merchant,
            category: 'Expense',
            cents: transaction.cents,
          ),
        ],
      };

  static const searchItems =
      <({String name, String store, int day, int cents, int card})>[
        (
          name: 'Latte',
          store: 'Blue Bottle Coffee',
          day: 24,
          cents: 350,
          card: 1,
        ),
        (
          name: 'Matcha latte',
          store: 'Starbucks',
          day: 20,
          cents: 495,
          card: 2,
        ),
        (
          name: 'Vanilla latte',
          store: 'Joe Coffee',
          day: 18,
          cents: 575,
          card: 4,
        ),
        (
          name: 'Iced latte',
          store: 'Blue Bottle Coffee',
          day: 12,
          cents: 525,
          card: 1,
        ),
        (name: 'Chai latte', store: 'Joe Coffee', day: 7, cents: 471, card: 4),
      ];
}
