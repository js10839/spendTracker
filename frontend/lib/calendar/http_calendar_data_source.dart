import '../api/api_client.dart';
import 'calendar_data_source.dart';
import 'calendar_dates.dart';
import 'calendar_models.dart';

/// The caller owns the shared ApiClient and supplies its existing access token.
class HttpCalendarDataSource implements CalendarDataSource {
  const HttpCalendarDataSource(this.api);
  final ApiClient api;

  @override
  Future<CalendarPeriod> loadCalendar({
    required String ledgerId,
    required DateTime anchorDate,
    String? paymentMethodId,
  }) async => _decode(
    await api.getJson(
      ['ledgers', ledgerId, 'calendar'],
      queryParameters: {
        'anchor_date': calendarDateKey(anchorDate),
        'payment_method_id': ?paymentMethodId,
      },
    ),
    CalendarPeriod.fromJson,
  );

  @override
  Future<CalendarNote?> saveNote({
    required String ledgerId,
    required DateTime date,
    required String content,
  }) async {
    final json = await api.putJson(
      ['ledgers', ledgerId, 'day-notes', calendarDateKey(date)],
      body: {'content': content},
    );
    return json == null ? null : _decode(json, CalendarNote.fromJson);
  }

  T _decode<T>(Object? json, T Function(Map<String, dynamic>) decode) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Expected an API JSON object');
    }
    try {
      return decode(json);
    } on TypeError {
      throw const FormatException('API JSON fields did not match the schema');
    } on ArgumentError {
      throw const FormatException('API JSON fields contained invalid values');
    }
  }
}
