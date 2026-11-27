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
    required this.statements,
    required this.daily,
    required this.yearly,
    required this.paymentMethods,
    required this.categories,
  });

  final int monthlySpendingCents;
  final List<DashboardStatement> statements;
  final List<DashboardBucket> daily;
  final List<DashboardBucket> yearly;
  final List<DashboardAmount> paymentMethods;
  final List<DashboardAmount> categories;
}

typedef DashboardAmount = ({String name, int cents, Color color});
typedef DashboardBucket = ({DateTime date, int cents});

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
    final result = await api.getJson(
      ['ledgers', ledgerId, 'dashboard'],
      queryParameters: {
        'as_of': calendarDateKey(today),
        if (month != null) ...{
          'month': calendarDateKey(month),
          'year': '${month.year}',
        },
      },
    ) as Map<String, dynamic>;
    final monthly = result['payment_method_breakdown'] as Map<String, dynamic>;
    final statements = result['card_statements'] as List<dynamic>;
    final categories =
        result['category_breakdown']['categories'] as List<dynamic>;
    return DashboardSummary(
      monthlySpendingCents: monthly['total_cents'] as int,
      statements: List.unmodifiable(
        statements.map(
          (item) => DashboardStatement.fromJson(item as Map<String, dynamic>),
        ),
      ),
      daily: _buckets(result['monthly_spending']),
      yearly: _buckets(result['yearly_spending']),
      paymentMethods: [
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
