import '../home/home_preview_data.dart';
import 'dashboard_repository.dart';

typedef DashboardPreviewTransaction = ({
  DateTime date,
  int card,
  String merchant,
  int cents,
});

/// Local monthly-chart samples, independent of Supabase, login, and the API.
///
/// Fixed at August 31, 2026 so the whole month can be previewed. Card indices,
/// names and colors follow HomePreviewData; these are a separate transaction set
/// and do not change or reconcile the existing Home screen's example totals.
/// Aggregation here is only for the prototype; real charts use backend totals.
abstract final class DashboardPreviewData {
  static final asOf = DateTime(2026, 8, 31);
  static final month = DateTime(2026, 8);

  // Stable sample UUIDs for Chase, Amex, Cash and BofA, respectively.
  static const paymentMethodIds = [
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000004',
  ];

  static const _purchases = <({String merchant, int cents})>[
    (merchant: 'Blue Bottle Coffee', cents: 575),
    (merchant: 'Trader Joe’s', cents: 6842),
    (merchant: 'Sweetgreen', cents: 1845),
    (merchant: 'Shell', cents: 5290),
    (merchant: 'Target', cents: 4236),
    (merchant: 'Local bakery', cents: 925),
    (merchant: 'Costco', cents: 14872),
    (merchant: 'Metro fare', cents: 300),
    (merchant: 'Neighborhood restaurant', cents: 3875),
    (merchant: 'Pharmacy', cents: 2139),
  ];

  /// Deterministic purchases: 2–4 per active day and two empty days.
  static final transactions = List<DashboardPreviewTransaction>.unmodifiable([
    for (var day = 1; day <= 31; day++)
      if (day != 7 && day != 21)
        for (var purchase = 0; purchase < 2 + day % 3; purchase++)
          (
            date: DateTime(2026, 8, day),
            card: 1 + (day + purchase) % 4,
            merchant:
                _purchases[(day + purchase * 3) % _purchases.length].merchant,
            cents:
                _purchases[(day + purchase * 3) % _purchases.length].cents +
                (day % 5) * 100,
          ),
  ]);

  /// Same shape as the dashboard response's monthly_spending section.
  /// Amounts are integer cents. Fresh maps allow independent preview consumers.
  static Map<String, Object?> get monthlySpending => {
    'start_date': '2026-08-01',
    'end_date': '2026-08-31',
    'buckets': [for (var day = 1; day <= 31; day++) _bucket(day)],
  };

  static Map<String, Object?> _bucket(int day) {
    final totals = <int, int>{};
    for (final transaction in transactions) {
      if (transaction.date.day == day) {
        totals.update(
          transaction.card,
          (cents) => cents + transaction.cents,
          ifAbsent: () => transaction.cents,
        );
      }
    }
    final cards = totals.keys.toList()
      ..sort(
        (a, b) => HomePreviewData.cardNames[a].compareTo(
          HomePreviewData.cardNames[b],
        ),
      );
    return {
      'date': '2026-08-${day.toString().padLeft(2, '0')}',
      'total_cents': totals.values.fold<int>(0, (sum, cents) => sum + cents),
      'payment_methods': [
        for (final card in cards)
          {
            'payment_method_id': paymentMethodIds[card - 1],
            'name': HomePreviewData.cardNames[card],
            'color':
                '#${HomePreviewData.cardColors[card].toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            'total_cents': totals[card]!,
          },
      ],
    };
  }
}

final dashboardGuestToday = DateTime.utc(2026, 8, 24);

Iterable<DashboardPreviewTransaction> _guestPurchases(DateTime month) sync* {
  final total = month.year == 2026 ? _guestSpending[month.month] : null;
  if (total == null) return;

  final lastDay = month.month == 8
      ? 24
      : DateTime.utc(month.year, month.month + 1, 0).day;
  final entries = DashboardPreviewData.transactions
      .where((entry) => entry.date.day <= lastDay)
      .toList();
  final weight = entries.fold<int>(0, (sum, entry) => sum + entry.cents);
  var cumulativeWeight = 0;
  var allocated = 0;
  // Scale the shared sample purchases without losing cents.
  for (final entry in entries) {
    cumulativeWeight += entry.cents;
    final next = cumulativeWeight * total ~/ weight;
    yield (
      date: DateTime.utc(month.year, month.month, entry.date.day),
      card: entry.card,
      merchant: entry.merchant,
      cents: next - allocated,
    );
    allocated = next;
  }
}

final _guestRollingStart = dashboardRollingStart(dashboardGuestToday);
final _guestRollingPurchases = [
  ..._guestPurchases(DateTime.utc(2026, 7))
      .where((entry) => !entry.date.isBefore(_guestRollingStart)),
  ..._guestPurchases(DateTime.utc(2026, 8)),
];

DashboardSummary dashboardGuestSummary(DateTime month, {bool rolling = false}) {
  final start = rolling
      ? _guestRollingStart
      : DateTime.utc(month.year, month.month);
  final end = rolling
      ? dashboardGuestToday
      : DateTime.utc(month.year, month.month + 1, 0);
  final totals = <int, int>{};
  final categories = <String, int>{};
  final days = <DateTime, int>{};
  for (final entry
      in rolling ? _guestRollingPurchases : _guestPurchases(month)) {
    totals.update(
      entry.card,
      (value) => value + entry.cents,
      ifAbsent: () => entry.cents,
    );
    days.update(
      entry.date,
      (value) => value + entry.cents,
      ifAbsent: () => entry.cents,
    );
    final name = switch (entry.merchant) {
      'Shell' || 'Metro fare' => 'Transport',
      'Sweetgreen' ||
      'Blue Bottle Coffee' ||
      'Neighborhood restaurant' => 'Dining',
      'Trader Joe’s' || 'Costco' || 'Local bakery' => 'Food',
      'Target' => 'Living',
      _ => 'Other',
    };
    categories.update(
      name,
      (value) => value + entry.cents,
      ifAbsent: () => entry.cents,
    );
  }
  final total = totals.values.fold<int>(0, (sum, cents) => sum + cents);
  final sortedMethods = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final sortedCategories = categories.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return DashboardSummary(
    monthlySpendingCents: rolling ? _guestSpending[8]! : total,
    rollingSpendingCents: _guestRollingPurchases.fold(
      0,
      (sum, entry) => sum + entry.cents,
    ),
    statements: [
      DashboardStatement(
        name: HomePreviewData.cardNames[1],
        color: HomePreviewData.cardColors[1],
        totalCents: 48230,
        start: DateTime.utc(2026, 8, 6),
        end: DateTime.utc(2026, 9, 5),
        spentThrough: DateTime.utc(2026, 8, 24),
      ),
      DashboardStatement(
        name: HomePreviewData.cardNames[2],
        color: HomePreviewData.cardColors[2],
        totalCents: 9620,
        start: DateTime.utc(2026, 8, 16),
        end: DateTime.utc(2026, 9, 15),
        spentThrough: DateTime.utc(2026, 8, 24),
      ),
    ],
    daily: [
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      )
        (date: day, cents: days[day] ?? 0),
    ],
    yearly: [
      for (var number = 1; number <= 12; number++)
        (
          date: DateTime.utc(month.year, number),
          cents: month.year == 2026 ? _guestSpending[number] ?? 0 : 0,
        ),
    ],
    paymentMethods: [
      for (final entry in sortedMethods)
        (
          name: HomePreviewData.cardNames[entry.key],
          cents: entry.value,
          color: HomePreviewData.cardColors[entry.key],
        ),
    ],
    categories: [
      for (final (index, entry) in sortedCategories.indexed)
        (
          name: entry.key,
          cents: entry.value,
          color: dashboardCategoryColors[index],
        ),
    ],
  );
}

const _guestSpending = {
  3: 174220,
  4: 196000,
  5: 210000,
  6: 185000,
  7: 242200,
  8: 81245,
};

Map<DateTime, int> dashboardGuestIncome() => {
  for (var month = 3; month <= 7; month++) DateTime.utc(2026, month): 240000,
  DateTime.utc(2026, 8): 76745,
};
