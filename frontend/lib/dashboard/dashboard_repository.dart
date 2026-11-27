import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../calendar/calendar_dates.dart';
import '../data/ledgers/ledger_repository.dart';
import '../design_system/tokens.dart';

class DashboardStatement {
  const DashboardStatement({
    required this.name,
    required this.color,
    required this.totalCents,
    required this.start,
    required this.end,
    required this.spentThrough,
    this.topCategories = const [],
  });

  factory DashboardStatement.fromJson(Map<String, dynamic> json) {
    final hex = json['color'] as String;
    return DashboardStatement(
      name: json['name'] as String,
      color: _parseColor(hex),
      totalCents: json['total_cents'] as int,
      start: parseCalendarDate(json['start_date'] as String),
      end: parseCalendarDate(json['end_date'] as String),
      spentThrough: parseCalendarDate(json['spent_through'] as String),
      topCategories: [
        for (final entry in json['top_categories'] as List<dynamic>)
          (
            name: entry['name'] as String,
            amountCents: entry['amount_cents'] as int,
          ),
      ],
    );
  }

  final String name;
  final Color color;
  final int totalCents;
  final DateTime start;
  final DateTime end;
  final DateTime spentThrough;
  final List<({String name, int amountCents})> topCategories;
}

class DashboardSummary {
  const DashboardSummary({
    required this.monthlySpendingCents,
    required this.rollingSpendingCents,
    required this.statements,
    required this.daily,
    required this.yearly,
    required this.paymentMethods,
    required this.categories,
  });

  final int monthlySpendingCents;
  final int rollingSpendingCents;
  final List<DashboardStatement> statements;
  final List<DashboardBucket> daily;
  final List<DashboardBucket> yearly;
  final List<DashboardAmount> paymentMethods;
  final List<DashboardAmount> categories;
}

typedef DashboardAmount = ({String name, int cents, Color color});
typedef DashboardBucket = ({DateTime date, int cents});

DateTime dashboardRollingStart(DateTime today) =>
    calendarDate(today).subtract(const Duration(days: 29));

const dashboardCategoryColors = [
  AppPalette.accentGreen,
  AppPalette.accentOrange,
  AppPalette.accentMagenta,
  AppPalette.accentYellow,
  AppTokens.borderStrong,
];

class DashboardRepository {
  const DashboardRepository(this.api);
  static DashboardRepository? instance;

  final ApiClient api;

  Future<String> _ledgerId() async {
    final ledgers = await LedgerRepository(api).list();
    if (ledgers.length != 1) {
      throw StateError('Expected one accessible ledger');
    }
    return ledgers.single.id;
  }

  Future<DashboardSummary> load(DateTime today, {DateTime? month}) async {
    final ledgerId = await _ledgerId();
    return _summary(await _fetch(ledgerId, today, month: month));
  }

  Future<Map<String, dynamic>> _fetch(
    String ledgerId,
    DateTime today, {
    DateTime? month,
    DateTime? categoryStart,
  }) async => await api.getJson(
    ['ledgers', ledgerId, 'dashboard'],
    queryParameters: {
      'as_of': calendarDateKey(today),
      if (month != null) ...{
        'month': calendarDateKey(month),
        'year': '${month.year}',
      },
      if (categoryStart != null) ...{
        'category_start': calendarDateKey(categoryStart),
        'category_end': calendarDateKey(today),
      },
    },
  ) as Map<String, dynamic>;

  Future<DashboardSummary> loadPast30Days(DateTime today) async {
    final end = calendarDate(today);
    final start = dashboardRollingStart(end);
    final current = DateTime.utc(end.year, end.month);
    final ledgerId = await _ledgerId();
    // Daily API buckets are calendar months. A 30-day span can touch three.
    final responses = await Future.wait([
      for (
        var month = DateTime.utc(start.year, start.month);
        !month.isAfter(current);
        month = DateTime.utc(month.year, month.month + 1)
      )
        _fetch(
          ledgerId,
          end,
          month: month,
          categoryStart: month == current ? start : null,
        ),
    ]);
    final result = responses.last;
    final days = <Map<String, dynamic>>[];
    final methods = <String, DashboardAmount>{};
    for (final response in responses) {
      for (final value
          in response['monthly_spending']['buckets'] as List<dynamic>) {
        final bucket = value as Map<String, dynamic>;
        final date = parseCalendarDate(bucket['date'] as String);
        if (date.isBefore(start) || date.isAfter(end)) continue;
        days.add(bucket);
        for (final method in bucket['payment_methods'] as List<dynamic>) {
          final id = method['payment_method_id'] as String;
          methods[id] = (
            name: method['name'] as String,
            color: _parseColor(method['color'] as String),
            cents: (methods[id]?.cents ?? 0) + (method['total_cents'] as int),
          );
        }
      }
    }
    final breakdown = methods.values.where((entry) => entry.cents != 0).toList()
      ..sort((a, b) {
        final amount = b.cents.compareTo(a.cents);
        return amount == 0 ? a.name.compareTo(b.name) : amount;
      });
    return _summary(
      result,
      daily: _buckets({'buckets': days}),
      paymentMethods: breakdown,
    );
  }

  DashboardSummary _summary(
    Map<String, dynamic> result, {
    List<DashboardBucket>? daily,
    List<DashboardAmount>? paymentMethods,
  }) {
    final monthly = result['payment_method_breakdown'] as Map<String, dynamic>;
    final statements = result['card_statements'] as List<dynamic>;
    final categories =
        result['category_breakdown']['categories'] as List<dynamic>;
    return DashboardSummary(
      monthlySpendingCents: monthly['total_cents'] as int,
      rollingSpendingCents: result['spending_30_days']['total_cents'] as int,
      statements: List.unmodifiable(
        statements.map(
          (item) => DashboardStatement.fromJson(item as Map<String, dynamic>),
        ),
      ),
      daily: daily ?? _buckets(result['monthly_spending']),
      yearly: _buckets(result['yearly_spending']),
      paymentMethods:
          paymentMethods ??
          [
            for (final method in monthly['payment_methods'] as List<dynamic>)
              (
                name: method['name'] as String,
                cents: method['total_cents'] as int,
                color: _parseColor(method['color'] as String),
              ),
          ],
      categories: [
        for (final (index, category) in categories.indexed)
          (
            name: category['name'] as String,
            cents: category['amount_cents'] as int,
            color:
                dashboardCategoryColors[index % dashboardCategoryColors.length],
          ),
      ],
    );
  }

  static List<DashboardBucket> _buckets(Map<String, dynamic> chart) => [
    for (final bucket in chart['buckets'] as List<dynamic>)
      (
        date: parseCalendarDate(bucket['date'] as String),
        cents: bucket['total_cents'] as int,
      ),
  ];

  Future<Map<DateTime, int>> loadReceivedIncome(DateTime today) async {
    final ledgerId = await _ledgerId();
    final records = await api.getJson([
      'ledgers',
      ledgerId,
      'income-records',
    ]) as List<dynamic>;
    final monthly = <DateTime, int>{};
    for (final record in records) {
      final date = parseCalendarDate(record['received_at'] as String);
      if (date.isAfter(calendarDate(today))) continue;
      final month = DateTime.utc(date.year, date.month);
      final amount = record['amount_cents'] as int;
      monthly.update(month, (value) => value + amount, ifAbsent: () => amount);
    }
    return monthly;
  }
}

Color _parseColor(String hex) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
    throw const FormatException('Invalid dashboard color');
  }
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
