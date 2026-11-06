import 'dart:async';

import 'package:spending_tracker/calendar/calendar.dart';

/// Explicit server fixtures, not a second implementation of billing rules.
Map<String, dynamic> calendarJson({
  String start = '2026-10-01',
  String end = '2026-10-31',
  String previous = '2026-09-30',
  String next = '2026-11-01',
  String? card,
}) => {
  'mode': card == null ? 'all' : 'card',
  'payment_method_id': card,
  'start_date': start,
  'end_date': end,
  'previous_anchor_date': previous,
  'next_anchor_date': next,
  'payment_methods': [
    {
      'id': 'chase',
      'name': 'Chase',
      'type': 'credit',
      'closing_day': 12,
      'color': '#1234AB',
    },
    {
      'id': 'cash',
      'name': 'Cash',
      'type': 'cash-like',
      'closing_day': null,
      'color': '#FCA05A',
    },
  ],
  'cards': [
    {
      'id': 'chase',
      'name': 'Chase',
      'type': 'credit',
      'closing_day': 12,
      'color': '#1234AB',
    },
  ],
  'days': [
    for (
      var date = parseCalendarDate(start);
      !date.isAfter(parseCalendarDate(end));
      date = date.add(const Duration(days: 1))
    )
      {
        'date': calendarDateKey(date),
        'transactions': <Object>[],
        'dots': <Object>[],
        'income': <Object>[],
        'closing_cards': <Object>[],
        'note': null,
        'spending_cents': 0,
        'received_income_cents': 0,
      },
  ],
};

Map<String, dynamic> detailedDayJson() => {
  'date': '2026-10-20',
  'transactions': [
    {
      'id': 'purchase',
      'ledger_id': 'personal',
      'payment_method_id': 'chase',
      'merchant': 'Cafe',
      'transacted_at': '2026-10-20',
      'memo': 'Receipt note',
      'source': 'manual',
      'total_cents': 650,
      'tax_cents': 50,
      'tip_cents': 100,
      'items': [
        {
          'id': 'coffee',
          'name': 'Coffee',
          'category_id': 'dining',
          'amount_cents': 500,
        },
      ],
    },
  ],
  'dots': [
    {
      'payment_method_id': 'chase',
      'label': 'Chase',
      'color': '#1234AB',
      'transaction_count': 1,
    },
  ],
  'income': [
    {
      'status': 'planned',
      'income_type': 'paycheck',
      'amount_cents': 10000,
      'display_date': '2026-10-20',
      'income_source_id': 'salary',
      'income_record_id': null,
      'payment_method_id': null,
      'from_name': 'Employer',
      'expected_date': '2026-10-21',
      'received_at': null,
      'memo': 'Income note',
    },
  ],
  'closing_cards': [
    {
      'id': 'other',
      'name': 'Other',
      'type': 'credit',
      'closing_day': 20,
      'color': '#FF0000',
    },
  ],
  'note': {
    'id': 'note',
    'ledger_id': 'personal',
    'note_date': '2026-10-20',
    'content': 'Day note',
  },
  'spending_cents': 650,
  'received_income_cents': 0,
};

class CalendarRequest {
  CalendarRequest(this.ledgerId, this.anchorDate, this.paymentMethodId);
  final String ledgerId;
  final DateTime anchorDate;
  final String? paymentMethodId;
}

class FakeCalendarDataSource implements CalendarDataSource {
  CalendarPeriod response = CalendarPeriod.fromJson(calendarJson());
  Future<CalendarPeriod> Function(CalendarRequest)? loader;
  final requests = <CalendarRequest>[];
  final writes = <({String ledgerId, DateTime date, String content})>[];
  Object? saveError;
  Completer<void>? saveGate;

  @override
  Future<CalendarPeriod> loadCalendar({
    required String ledgerId,
    required DateTime anchorDate,
    String? paymentMethodId,
  }) async {
    final request = CalendarRequest(ledgerId, anchorDate, paymentMethodId);
    requests.add(request);
    return loader == null ? response : await loader!(request);
  }

  @override
  Future<CalendarNote?> saveNote({
    required String ledgerId,
    required DateTime date,
    required String content,
  }) async {
    writes.add((ledgerId: ledgerId, date: date, content: content));
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
    return content.isEmpty
        ? null
        : CalendarNote(
            id: 'note',
            ledgerId: ledgerId,
            date: date,
            content: content,
          );
  }
}
