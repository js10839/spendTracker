import 'calendar_dates.dart';
import 'calendar_models.dart';

/// Combines a whole window once; selecting a day requires no extra requests.
Map<DateTime, CalendarDay> buildCalendarDays({
  required String ledgerId,
  required CalendarWindow window,
  required List<CalendarPaymentMethod> paymentMethods,
  required List<CalendarTransaction> transactions,
  required List<CalendarIncome> income,
  required List<CalendarNote> notes,
  String? selectedCardId,
}) {
  final methods = {for (final method in paymentMethods) method.id: method};
  final transactionsByDate = <DateTime, List<CalendarTransaction>>{};
  for (final transaction in transactions) {
    if (transaction.ledgerId != ledgerId ||
        !window.contains(transaction.date) ||
        (selectedCardId != null &&
            transaction.paymentMethodId != selectedCardId)) {
      continue;
    }
    transactionsByDate.putIfAbsent(transaction.date, () => []).add(transaction);
  }
  final incomeByDate = <DateTime, List<CalendarIncome>>{};
  for (final entry in income) {
    if (window.contains(entry.displayDate)) {
      incomeByDate.putIfAbsent(entry.displayDate, () => []).add(entry);
    }
  }
  final notesByDate = {
    for (final note in notes)
      if (note.ledgerId == ledgerId &&
          window.contains(note.date) &&
          note.content.trim().isNotEmpty)
        note.date: note,
  };
  return Map.unmodifiable({
    for (final date in window.dates)
      date: _buildDay(
        date,
        transactionsByDate[date] ?? [],
        incomeByDate[date] ?? [],
        notesByDate[date],
        methods,
      ),
  });
}

CalendarDay _buildDay(
  DateTime date,
  List<CalendarTransaction> transactions,
  List<CalendarIncome> income,
  CalendarNote? note,
  Map<String, CalendarPaymentMethod> methods,
) {
  transactions.sort((a, b) => a.id.compareTo(b.id));
  final counts = <String, int>{};
  for (final transaction in transactions) {
    counts.update(transaction.paymentMethodId, (n) => n + 1, ifAbsent: () => 1);
  }
  final methodIds = counts.keys.toList()..sort();
  final closingCards =
      methods.values
          .where(
            (method) =>
                method.isCredit &&
                cardClosingDate(date.year, date.month, method.closingDay!) ==
                    date,
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  return CalendarDay(
    date: date,
    transactions: transactions,
    dots: [
      for (final id in methodIds)
        CalendarTransactionDot(
          paymentMethodId: id,
          label: methods[id]?.name ?? 'Unknown payment method',
          color: methods[id]?.color,
          transactionCount: counts[id]!,
        ),
    ],
    income: income,
    closingCards: closingCards,
    note: note,
  );
}
