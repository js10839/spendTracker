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

/// Dashboard screen samples share the chart fixture and use the Figma preview date.
DashboardSummary dashboardGuestSummary(DateTime month) {
  final current = month.year == 2026 && month.month == 8;
  final totalForMonth = month.year == 2026 ? _guestSpending[month.month] : null;
  final totals = <int, int>{};
  final categories = <String, int>{};
  final days = <int, int>{};
  if (totalForMonth != null) {
    final lastDay = current
        ? 24
        : DateTime.utc(month.year, month.month + 1, 0).day;
    final entries = DashboardPreviewData.transactions
        .where((entry) => entry.date.day <= lastDay)
        .toList();
    final weight = entries.fold<int>(0, (value, entry) => value + entry.cents);
    var cumulativeWeight = 0;
    var allocated = 0;
    // Scale the shared sample purchases to the preview total without losing cents.
    for (final entry in entries) {
      cumulativeWeight += entry.cents;
      final next = cumulativeWeight * totalForMonth ~/ weight;
      final amount = next - allocated;
      allocated = next;
      totals.update(
        entry.card,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
      days.update(
        entry.date.day,
        (value) => value + amount,
        ifAbsent: () => amount,
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
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
  }
  final total = totals.values.fold<int>(0, (sum, cents) => sum + cents);
  final sortedMethods = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final sortedCategories = categories.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return DashboardSummary(
    monthlySpendingCents: total,
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
        var day = 1;
        day <= DateTime.utc(month.year, month.month + 1, 0).day;
        day++
      )
        (
          date: DateTime.utc(month.year, month.month, day),
          cents: days[day] ?? 0,
        ),
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
