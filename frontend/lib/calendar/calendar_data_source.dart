import 'calendar_models.dart';

/// Backend selects, filters and aggregates the full window in one request.
abstract interface class CalendarDataSource {
  Future<CalendarPeriod> loadCalendar({
    required String ledgerId,
    required DateTime anchorDate,
    String? paymentMethodId,
  });

  /// Existing PUT /ledgers/{ledgerId}/day-notes/{date}; empty content clears.
  Future<CalendarNote?> saveNote({
    required String ledgerId,
    required DateTime date,
    required String content,
  });
}
