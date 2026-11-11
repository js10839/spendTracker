import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/calendar/calendar.dart';

void main() {
  test('date-only parsing preserves fields and rejects invalid dates', () {
    expect(calendarDate(DateTime(2026, 11, 1, 23)), DateTime.utc(2026, 11, 1));
    expect(parseCalendarDate('2024-02-29'), DateTime.utc(2024, 2, 29));
    for (final invalid in [
      '2026-02-29',
      '2026-11-31',
      '2026-1-01',
      '2026-11-01T00:00:00Z',
    ]) {
      expect(() => parseCalendarDate(invalid), throwsFormatException);
    }
  });

  test('server range is padded Sunday-first without adding outside dates', () {
    final window = CalendarWindow(
      DateTime.utc(2026, 10, 13),
      DateTime.utc(2026, 11, 13),
    );
    expect(window.gridDates.take(2), [null, null]);
    expect(window.gridDates.whereType<DateTime>().length, 31);
    expect(window.gridDates.length % 7, 0);
    expect(window.contains(DateTime(2026, 11, 12)), isTrue);
    expect(window.contains(DateTime(2026, 11, 13)), isFalse);
    expect(
      () => CalendarWindow(DateTime(2026), DateTime(2026)),
      throwsArgumentError,
    );
  });
}
