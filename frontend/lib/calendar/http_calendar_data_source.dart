import '../api/api_client.dart';
import 'calendar_data_source.dart';
import 'calendar_dates.dart';
import 'calendar_models.dart';

/// The real FastAPI adapter. The caller owns the shared ApiClient lifecycle.
class HttpCalendarDataSource implements CalendarDataSource {
  const HttpCalendarDataSource(this.api);

  final ApiClient api;

  @override
  Future<List<CalendarPaymentMethod>> loadPaymentMethods() async => _readList(
    await api.getJson(['users', 'me', 'payment-methods']),
    CalendarPaymentMethod.fromJson,
  );

  @override
  Future<List<CalendarTransaction>> loadTransactions({
    required String ledgerId,
    required CalendarWindow window,
    String? paymentMethodId,
  }) async => _readList(
    await api.getJson(
      ['ledgers', ledgerId, 'transactions'],
      queryParameters: {
        ...window.queryParameters,
        'payment_method_id': ?paymentMethodId,
      },
    ),
    CalendarTransaction.fromJson,
  );

  @override
  Future<List<CalendarIncome>> loadIncome({
    required String ledgerId,
    required CalendarWindow window,
  }) async => _readList(
    await api.getJson([
      'ledgers',
      ledgerId,
      'income-calendar',
    ], queryParameters: window.queryParameters),
    CalendarIncome.fromJson,
  );

  @override
  Future<List<CalendarNote>> loadNotes({
    required String ledgerId,
    required CalendarWindow window,
  }) async => _readList(
    await api.getJson([
      'ledgers',
      ledgerId,
      'day-notes',
    ], queryParameters: window.queryParameters),
    CalendarNote.fromJson,
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

  List<T> _readList<T>(Object? json, T Function(Map<String, dynamic>) decode) {
    if (json is! List) throw const FormatException('Expected an API JSON list');
    return List.unmodifiable(json.map((item) => _decode(item, decode)));
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
