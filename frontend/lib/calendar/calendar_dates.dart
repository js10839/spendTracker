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

DateTime cardClosingDate(int year, int month, int closingDay) {
  RangeError.checkValueInInterval(closingDay, 1, 31, 'closingDay');
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, closingDay > lastDay ? lastDay : closingDay);
}

/// Start is inclusive; endExclusive belongs to the next period.
class CalendarWindow {
  CalendarWindow(DateTime start, DateTime endExclusive)
    : start = calendarDate(start),
      endExclusive = calendarDate(endExclusive) {
    if (!this.start.isBefore(this.endExclusive)) {
      throw ArgumentError('Calendar window must contain at least one date');
    }
  }

  factory CalendarWindow.containing(DateTime date, {int? closingDay}) {
    final day = calendarDate(date);
    if (closingDay == null) {
      return CalendarWindow(
        DateTime.utc(day.year, day.month),
        DateTime.utc(day.year, day.month + 1),
      );
    }
    final close = cardClosingDate(day.year, day.month, closingDay);
    final closingMonth = DateTime.utc(
      day.year,
      day.month + (day.isAfter(close) ? 1 : 0),
    );
    return CalendarWindow.endingIn(closingMonth, closingDay);
  }

  /// The cycle ending at this month's (clamped) closing date.
  factory CalendarWindow.endingIn(DateTime month, int closingDay) =>
      CalendarWindow(
        cardClosingDate(
          month.year,
          month.month - 1,
          closingDay,
        ).add(const Duration(days: 1)),
        cardClosingDate(
          month.year,
          month.month,
          closingDay,
        ).add(const Duration(days: 1)),
      );

  final DateTime start;
  final DateTime endExclusive;

  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));

  /// Query parameters for the existing inclusive-range FastAPI endpoints.
  Map<String, String> get queryParameters => {
    'start_date': calendarDateKey(start),
    'end_date': calendarDateKey(endInclusive),
  };

  bool contains(DateTime date) {
    final day = calendarDate(date);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  CalendarWindow shifted(int periods, {int? closingDay}) {
    if (closingDay == null) {
      return CalendarWindow.containing(
        DateTime.utc(start.year, start.month + periods),
      );
    }
    final end = endInclusive;
    return CalendarWindow.endingIn(
      DateTime.utc(end.year, end.month + periods),
      closingDay,
    );
  }

  List<DateTime> get dates => List.unmodifiable([
    for (
      var day = start;
      day.isBefore(endExclusive);
      day = day.add(const Duration(days: 1))
    )
      day,
  ]);

  /// Sunday-first grid; null slots are padding, never outside-window dates.
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
