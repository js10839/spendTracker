import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/calendar/calendar.dart';

void main() {
  test(
    'All covers the whole month, including leap days and year boundaries',
    () {
      final leap = CalendarWindow.containing(DateTime(2024, 2, 20));
      expect(leap.start, DateTime.utc(2024, 2));
      expect(leap.endInclusive, DateTime.utc(2024, 2, 29));
      expect(leap.dates, hasLength(29));
      final december = CalendarWindow.containing(DateTime(2026, 12, 31));
      expect(december.shifted(1).start, DateTime.utc(2027, 1));
      expect(december.shifted(1).shifted(-1).start, december.start);
      expect(december.contains(DateTime(2027, 1)), isFalse);
    },
  );

  test('closing on the 12th gives a cycle from the 13th through the 12th', () {
    final window = CalendarWindow.containing(
      DateTime(2026, 10, 20),
      closingDay: 12,
    );
    expect(window.start, DateTime.utc(2026, 10, 13));
    expect(window.endExclusive, DateTime.utc(2026, 11, 13));
    expect(window.queryParameters, {
      'start_date': '2026-10-13',
      'end_date': '2026-11-12',
    });
    expect(window.contains(DateTime(2026, 11, 12, 23, 59)), isTrue);
    expect(window.contains(DateTime(2026, 11, 13)), isFalse);
    expect(
      CalendarWindow.containing(
        DateTime(2026, 10, 12),
        closingDay: 12,
      ).endInclusive,
      DateTime.utc(2026, 10, 12),
    );
  });

  test('month-end starts follow the actual previous closing date', () {
    final february = CalendarWindow.containing(
      DateTime(2024, 2, 29),
      closingDay: 31,
    );
    expect(february.start, DateTime.utc(2024, 2));
    expect(february.endInclusive, DateTime.utc(2024, 2, 29));
    final march = february.shifted(1, closingDay: 31);
    expect(march.start, DateTime.utc(2024, 3));
    expect(march.endInclusive, DateTime.utc(2024, 3, 31));
    final thirtieth = CalendarWindow.containing(
      DateTime(2025, 3, 1),
      closingDay: 30,
    );
    expect(thirtieth.start, DateTime.utc(2025, 3));
    expect(thirtieth.endInclusive, DateTime.utc(2025, 3, 30));
    expect(
      thirtieth.shifted(1, closingDay: 30).start,
      DateTime.utc(2025, 3, 31),
    );
  });

  test('every closing day partitions dates without gaps or overlaps', () {
    for (var closingDay = 1; closingDay <= 31; closingDay++) {
      for (var year = 2023; year <= 2027; year++) {
        for (var month = 1; month <= 12; month++) {
          final window = CalendarWindow.endingIn(
            DateTime.utc(year, month),
            closingDay,
          );
          final next = window.shifted(1, closingDay: closingDay);
          expect(next.start, window.endExclusive);
          expect(next.shifted(-1, closingDay: closingDay).start, window.start);
          expect(window.dates.length, inInclusiveRange(28, 31));
          for (final day in window.dates) {
            final containing = CalendarWindow.containing(
              day,
              closingDay: closingDay,
            );
            expect(containing.start, window.start);
            expect(containing.endExclusive, window.endExclusive);
          }
        }
      }
    }
  });

  test('range grid preserves weekdays and pads with blanks only', () {
    final window = CalendarWindow.containing(
      DateTime(2026, 10, 20),
      closingDay: 12,
    );
    final slots = window.gridDates;
    expect(slots.length % 7, 0);
    expect(slots.whereType<DateTime>().toList(), window.dates);
    expect(slots.take(2), everyElement(isNull)); // October 13 is Tuesday.
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] != null) expect(slots[i]!.weekday % 7, i % 7);
    }
    expect(CalendarWindow.containing(DateTime(2026, 2)).gridDates.length, 28);
  });

  test('date-only normalization copies fields without timezone conversion', () {
    final local = DateTime(2026, 3, 8, 23, 59);
    expect(calendarDate(local), DateTime.utc(2026, 3, 8));
    final window = CalendarWindow.containing(local);
    expect(window.dates.toSet(), hasLength(31));
    expect(window.dates.every((d) => d.isUtc && d.hour == 0), isTrue);
    expect(parseCalendarDate('2024-02-29'), DateTime.utc(2024, 2, 29));
    for (final invalid in [
      '2025-02-29',
      '2026-04-31',
      '2026-1-1',
      '2026-10-31T12:00:00Z',
      'nonsense',
    ]) {
      expect(() => parseCalendarDate(invalid), throwsFormatException);
    }
  });

  test('rejects invalid windows and closing days', () {
    expect(
      () => CalendarWindow(DateTime(2026), DateTime(2026)),
      throwsArgumentError,
    );
    expect(() => cardClosingDate(2026, 2, 0), throwsRangeError);
    expect(() => cardClosingDate(2026, 2, 32), throwsRangeError);
  });
}
