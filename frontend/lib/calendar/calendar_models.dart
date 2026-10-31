import 'calendar_dates.dart';

/// Uses the existing payment-method API's user-chosen color verbatim.
class CalendarPaymentMethod {
  CalendarPaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    this.closingDay,
  }) {
    if (type != 'credit' && type != 'cash-like') {
      throw ArgumentError.value(type, 'type');
    }
    if (type == 'credit') {
      RangeError.checkValueInInterval(closingDay ?? 0, 1, 31, 'closingDay');
    } else if (closingDay != null) {
      throw ArgumentError('Cash-like methods cannot have a closing day');
    }
  }

  factory CalendarPaymentMethod.fromJson(Map<String, dynamic> json) =>
      CalendarPaymentMethod(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        color: json['color'] as String,
        closingDay: json['closing_day'] as int?,
      );

  final String id;
  final String name;
  final String type;
  final String color;
  final int? closingDay;
  bool get isCredit => type == 'credit';
}

class CalendarTransactionItem {
  const CalendarTransactionItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.amountCents,
  });

  factory CalendarTransactionItem.fromJson(Map<String, dynamic> json) =>
      CalendarTransactionItem(
        id: json['id'] as String,
        name: json['name'] as String,
        categoryId: json['category_id'] as String,
        amountCents: json['amount_cents'] as int,
      );

  final String id;
  final String name;
  final String categoryId;
  final int amountCents;
}

class CalendarTransaction {
  CalendarTransaction({
    required this.id,
    required this.ledgerId,
    required this.paymentMethodId,
    required DateTime date,
    required this.totalCents,
    required this.taxCents,
    required this.tipCents,
    required this.source,
    required List<CalendarTransactionItem> items,
    this.merchant,
    this.memo,
  }) : date = calendarDate(date),
       items = List.unmodifiable(items);

  factory CalendarTransaction.fromJson(Map<String, dynamic> json) =>
      CalendarTransaction(
        id: json['id'] as String,
        ledgerId: json['ledger_id'] as String,
        paymentMethodId: json['payment_method_id'] as String,
        date: parseCalendarDate(json['transacted_at'] as String),
        totalCents: json['total_cents'] as int,
        taxCents: json['tax_cents'] as int,
        tipCents: json['tip_cents'] as int,
        source: json['source'] as String,
        merchant: json['merchant'] as String?,
        memo: json['memo'] as String?,
        items: (json['items'] as List<dynamic>)
            .map(
              (item) => CalendarTransactionItem.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  final String id;
  final String ledgerId;
  final String paymentMethodId;
  final DateTime date;
  final int totalCents;
  final int taxCents;
  final int tipCents;
  final String source;
  final String? merchant;
  final String? memo;
  final List<CalendarTransactionItem> items;
}

class CalendarIncome {
  CalendarIncome({
    required this.status,
    required this.incomeType,
    required this.amountCents,
    required DateTime displayDate,
    this.incomeSourceId,
    this.incomeRecordId,
    this.paymentMethodId,
    this.fromName,
    DateTime? expectedDate,
    DateTime? receivedAt,
    this.memo,
  }) : displayDate = calendarDate(displayDate),
       expectedDate = expectedDate == null ? null : calendarDate(expectedDate),
       receivedAt = receivedAt == null ? null : calendarDate(receivedAt);

  factory CalendarIncome.fromJson(Map<String, dynamic> json) => CalendarIncome(
    status: json['status'] as String,
    incomeType: json['income_type'] as String,
    amountCents: json['amount_cents'] as int,
    displayDate: parseCalendarDate(json['display_date'] as String),
    incomeSourceId: json['income_source_id'] as String?,
    incomeRecordId: json['income_record_id'] as String?,
    paymentMethodId: json['payment_method_id'] as String?,
    fromName: json['from_name'] as String?,
    expectedDate: json['expected_date'] == null
        ? null
        : parseCalendarDate(json['expected_date'] as String),
    receivedAt: json['received_at'] == null
        ? null
        : parseCalendarDate(json['received_at'] as String),
    memo: json['memo'] as String?,
  );

  final String status;
  final String incomeType;
  final int amountCents;
  final DateTime displayDate;
  final String? incomeSourceId;
  final String? incomeRecordId;
  final String? paymentMethodId;
  final String? fromName;
  final DateTime? expectedDate;
  final DateTime? receivedAt;
  final String? memo;
}

class CalendarNote {
  CalendarNote({
    required this.id,
    required this.ledgerId,
    required DateTime date,
    required this.content,
  }) : date = calendarDate(date);

  factory CalendarNote.fromJson(Map<String, dynamic> json) => CalendarNote(
    id: json['id'] as String,
    ledgerId: json['ledger_id'] as String,
    date: parseCalendarDate(json['note_date'] as String),
    content: json['content'] as String,
  );

  final String id;
  final String ledgerId;
  final DateTime date;
  final String content;
}

/// One indicator per payment method with transactions, not per purchase.
class CalendarTransactionDot {
  const CalendarTransactionDot({
    required this.paymentMethodId,
    required this.label,
    required this.color,
    required this.transactionCount,
  });

  final String paymentMethodId;
  final String label;

  /// Null means wallet metadata is unavailable; UI should use a neutral fallback.
  final String? color;
  final int transactionCount;
}

class CalendarDay {
  CalendarDay({
    required this.date,
    required List<CalendarTransaction> transactions,
    required List<CalendarTransactionDot> dots,
    required List<CalendarIncome> income,
    required List<CalendarPaymentMethod> closingCards,
    this.note,
  }) : transactions = List.unmodifiable(transactions),
       dots = List.unmodifiable(dots),
       income = List.unmodifiable(income),
       closingCards = List.unmodifiable(closingCards);

  final DateTime date;
  final List<CalendarTransaction> transactions;
  final List<CalendarTransactionDot> dots;
  final List<CalendarIncome> income;
  final List<CalendarPaymentMethod> closingCards;
  final CalendarNote? note;

  int get spendingCents => transactions.fold(0, (sum, t) => sum + t.totalCents);
  int get receivedIncomeCents => income
      .where((i) => i.status == 'received')
      .fold(0, (sum, i) => sum + i.amountCents);
}
