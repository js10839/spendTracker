/// 특정 월에 없는 마감일은 해당 월의 마지막 날로 보정한다.
DateTime closingDateForMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDay ? lastDay : day);
}

/// 오늘부터 적용되는 카드 사이클의 시작일과 마감일을 계산한다.
({DateTime start, DateTime end}) closingCycle(DateTime now, int day) {
  final today = DateTime(now.year, now.month, now.day);
  var end = closingDateForMonth(today.year, today.month, day);
  if (end.isBefore(today)) {
    end = closingDateForMonth(today.year, today.month + 1, day);
  }
  final previous = closingDateForMonth(end.year, end.month - 1, day);
  return (start: previous.add(const Duration(days: 1)), end: end);
}

/// 날짜의 영문 서수 표기를 만든다.
String ordinalDay(int day) {
  final suffix = day % 100 >= 11 && day % 100 <= 13
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$day$suffix';
}
