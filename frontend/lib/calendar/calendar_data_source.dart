import 'calendar_models.dart';

/// Backend selects, filters and aggregates the full window in one request.
abstract interface class CalendarDataSource {
  Future<CalendarPeriod> loadCalendar({
    required String ledgerId,
    required DateTime anchorDate,
    String? paymentMethodId,
  });

}
