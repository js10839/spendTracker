import 'dart:async';

import 'package:spending_tracker/calendar/calendar.dart';

List<CalendarPaymentMethod> testPaymentMethods() => [
  CalendarPaymentMethod(
    id: 'chase',
    name: 'Chase',
    type: 'credit',
    closingDay: 12,
    color: '#1234AB',
  ),
  CalendarPaymentMethod(
    id: 'amex',
    name: 'Amex',
    type: 'credit',
    closingDay: 20,
    color: '#AB3412',
  ),
  CalendarPaymentMethod(
    id: 'cash',
    name: 'Cash',
    type: 'cash-like',
    color: '#FCA05A',
  ),
];

CalendarTransaction testTransaction({
  String id = 'purchase',
  String methodId = 'chase',
  String date = '2026-10-20',
  String ledgerId = 'personal',
  int totalCents = 650,
}) => CalendarTransaction.fromJson({
  'id': id,
  'ledger_id': ledgerId,
  'payment_method_id': methodId,
  'merchant': 'Test Cafe',
  'transacted_at': date,
  'memo': 'Transaction memo',
  'source': 'manual',
  'total_cents': totalCents,
  'tax_cents': 50,
  'tip_cents': 100,
  'items': [
    {
      'id': 'item-$id',
      'name': 'Coffee',
      'category_id': 'dining',
      'amount_cents': totalCents - 150,
    },
  ],
});

CalendarIncome testIncome({
  String status = 'planned',
  String date = '2026-10-20',
  String? paymentMethodId,
  int amountCents = 10000,
}) => CalendarIncome.fromJson({
  'status': status,
  'income_type': 'paycheck',
  'amount_cents': amountCents,
  'display_date': date,
  'income_source_id': 'salary',
  'income_record_id': status == 'received' ? 'paycheck' : null,
  'payment_method_id': paymentMethodId,
  'from_name': 'Employer',
  'expected_date': '2026-10-21',
  'received_at': status == 'received' ? date : null,
  'memo': 'Income memo',
});

CalendarNote testNote({
  String date = '2026-10-20',
  String content = 'Day note',
  String ledgerId = 'personal',
}) => CalendarNote.fromJson({
  'id': 'note-$date',
  'ledger_id': ledgerId,
  'note_date': date,
  'content': content,
});

class WindowRequest {
  WindowRequest(this.ledgerId, this.window, [this.paymentMethodId]);
  final String ledgerId;
  final CalendarWindow window;
  final String? paymentMethodId;
}

/// Deliberately returns unfiltered fixtures: projections must enforce the range,
/// ledger, and card constraints even when the future adapter returns extra data.
class FakeCalendarDataSource implements CalendarDataSource {
  List<CalendarPaymentMethod> methods = testPaymentMethods();
  List<CalendarTransaction> transactions = [];
  List<CalendarIncome> income = [];
  List<CalendarNote> notes = [];
  int methodLoads = 0;
  final transactionRequests = <WindowRequest>[];
  final incomeRequests = <WindowRequest>[];
  final noteRequests = <WindowRequest>[];
  final noteWrites = <({String ledgerId, DateTime date, String content})>[];
  Object? methodsError;
  Object? incomeError;
  Object? notesError;
  Object? saveError;
  Future<List<CalendarPaymentMethod>> Function()? methodsLoader;
  Future<List<CalendarTransaction>> Function(WindowRequest)? transactionsLoader;
  Completer<void>? saveGate;

  @override
  Future<List<CalendarPaymentMethod>> loadPaymentMethods() async {
    methodLoads++;
    if (methodsError != null) throw methodsError!;
    return methodsLoader == null ? methods : await methodsLoader!();
  }

  @override
  Future<List<CalendarTransaction>> loadTransactions({
    required String ledgerId,
    required CalendarWindow window,
    String? paymentMethodId,
  }) async {
    final request = WindowRequest(ledgerId, window, paymentMethodId);
    transactionRequests.add(request);
    return transactionsLoader == null
        ? transactions
        : await transactionsLoader!(request);
  }

  @override
  Future<List<CalendarIncome>> loadIncome({
    required String ledgerId,
    required CalendarWindow window,
  }) async {
    incomeRequests.add(WindowRequest(ledgerId, window));
    if (incomeError != null) throw incomeError!;
    return income;
  }

  @override
  Future<List<CalendarNote>> loadNotes({
    required String ledgerId,
    required CalendarWindow window,
  }) async {
    noteRequests.add(WindowRequest(ledgerId, window));
    if (notesError != null) throw notesError!;
    return notes;
  }

  @override
  Future<CalendarNote?> saveNote({
    required String ledgerId,
    required DateTime date,
    required String content,
  }) async {
    noteWrites.add((ledgerId: ledgerId, date: date, content: content));
    if (saveGate != null) await saveGate!.future;
    if (saveError != null) throw saveError!;
    final note = content.trim().isEmpty
        ? null
        : testNote(
            date: calendarDateKey(date),
            content: content.trim(),
            ledgerId: ledgerId,
          );
    notes = [
      for (final old in notes)
        if (old.date != calendarDate(date) || old.ledgerId != ledgerId) old,
      ?note,
    ];
    return note;
  }
}
