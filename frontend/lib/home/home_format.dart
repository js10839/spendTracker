/// 센트 정수 금액을 화면용 달러 문자열로 바꾼다.
String formatHomeMoney(int cents) => '${cents < 0 ? '-' : ''}\$${(cents.abs() / 100).toStringAsFixed(2)}';

/// 홈에서 월 이름을 표시할 때 쓰는 약어다.
const homeMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
