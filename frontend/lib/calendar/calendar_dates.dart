/// Calendar values are date-only UTC containers, never converted with toUtc().
/// Copying year/month/day preserves the user's date across DST and time zones.
DateTime calendarDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

String calendarDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime parseCalendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Expected YYYY-MM-DD', value);
  }
  final date = DateTime.parse(value);
  if (calendarDateKey(date) != value) {
    throw FormatException('Invalid calendar date', value);
  }
  return calendarDate(date);
}

/// Server-supplied bounds; this class only supports local display/grid layout.
class CalendarWindow {
  CalendarWindow(DateTime start, DateTime endExclusive)
    : start = calendarDate(start),
      endExclusive = calendarDate(endExclusive) {
    if (!this.start.isBefore(this.endExclusive)) {
      throw ArgumentError('Calendar window must contain at least one date');
    }
  }

  final DateTime start;
  final DateTime endExclusive;
  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));

  bool contains(DateTime date) {
    final day = calendarDate(date);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  List<DateTime> get dates => List.unmodifiable([
    for (
      var day = start;
      day.isBefore(endExclusive);
      day = day.add(const Duration(days: 1))
    )
      day,
  ]);

  /// Sunday-first padding is presentation only, not a billing calculation.
  List<DateTime?> get gridDates {
    final slots = <DateTime?>[
      ...List<DateTime?>.filled(start.weekday % 7, null),
      ...dates,
    ];
    while (slots.length % 7 != 0) {
      slots.add(null);
    }
    return List.unmodifiable(slots);
  }
}
