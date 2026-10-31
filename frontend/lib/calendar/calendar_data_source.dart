import 'calendar_dates.dart';
import 'calendar_models.dart';

/// Transport boundary only: auth, HTTP, and Supabase initialization come later.
/// Implement with existing FastAPI endpoints; never query Supabase app tables.
abstract interface class CalendarDataSource {
  /// GET /users/me/payment-methods (all wallet methods, for colors/closings).
  Future<List<CalendarPaymentMethod>> loadPaymentMethods();

  /// GET /ledgers/{ledgerId}/transactions with window.queryParameters and,
  /// when supplied, payment_method_id. Null means all payment methods.
  Future<List<CalendarTransaction>> loadTransactions({
    required String ledgerId,
    required CalendarWindow window,
    String? paymentMethodId,
  });

  /// GET /ledgers/{ledgerId}/income-calendar; do not filter by selected card.
  Future<List<CalendarIncome>> loadIncome({
    required String ledgerId,
    required CalendarWindow window,
  });

  /// GET /ledgers/{ledgerId}/day-notes; do not filter by selected card.
  Future<List<CalendarNote>> loadNotes({
    required String ledgerId,
    required CalendarWindow window,
  });

  /// PUT /ledgers/{ledgerId}/day-notes/{date}, body {"content": content}.
  /// Empty content clears the note; the endpoint then returns null.
  Future<CalendarNote?> saveNote({
    required String ledgerId,
    required DateTime date,
    required String content,
  });
}
