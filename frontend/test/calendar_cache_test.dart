import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/calendar/calendar.dart';
import 'support/calendar_fixtures.dart';

/// 요청 날짜가 속한 월을 서버 응답으로 만드는 테스트 데이터다.
CalendarPeriod monthly(CalendarRequest request) {
  final date = request.anchorDate;
  final start = DateTime.utc(date.year, date.month);
  final next = DateTime.utc(date.year, date.month + 1);
  final json = calendarJson(start: calendarDateKey(start), end: calendarDateKey(next.subtract(const Duration(days: 1))), previous: calendarDateKey(start.subtract(const Duration(days: 1))), next: calendarDateKey(next), card: request.paymentMethodId);
  if (request.paymentMethodId == 'cash') json['mode'] = 'cash';
  return CalendarPeriod.fromJson(json);
}

void main() {
  test('현재와 양옆을 미리 조회하고 이동하면 먼 기간을 폐기한다', () async {
    final source = FakeCalendarDataSource()..loader = (request) async => monthly(request);
    final controller = CalendarController(ledgerId: 'personal', dataSource: source, clock: () => DateTime(2026, 11, 20));
    addTearDown(controller.dispose);
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(source.requests.length, 3);
    expect(controller.state.previousPeriod!.window.start, DateTime.utc(2026, 10, 1));
    expect(controller.state.nextPeriod!.window.start, DateTime.utc(2026, 12, 1));
    await controller.nextPeriod();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.window!.start, DateTime.utc(2026, 12, 1));
    expect(source.requests.length, 4);
    expect(controller.state.previousPeriod!.window.start, DateTime.utc(2026, 11, 1));
    expect(controller.state.nextPeriod!.window.start, DateTime.utc(2027, 1, 1));
    await controller.previousPeriod();
    await Future<void>.delayed(Duration.zero);
    expect(source.requests.length, 5);
    expect(source.requests.last.anchorDate, DateTime.utc(2026, 10, 31));
  });

  test('미리 조회 중 이동해도 현재 데이터를 유지하고 같은 요청을 공유한다', () async {
    final source = FakeCalendarDataSource();
    final gate = Completer<CalendarPeriod>();
    source.loader = (request) => request.anchorDate == DateTime.utc(2026, 12, 1) ? gate.future : Future.value(monthly(request));
    final controller = CalendarController(ledgerId: 'personal', dataSource: source, clock: () => DateTime(2026, 11, 20));
    addTearDown(controller.dispose);
    await controller.refresh();
    final moving = controller.nextPeriod();
    expect(controller.state.window!.start, DateTime.utc(2026, 11, 1));
    expect(controller.state.isLoading, isFalse);
    expect(source.requests.where((request) => request.anchorDate == DateTime.utc(2026, 12, 1)).length, 1);
    gate.complete(monthly(CalendarRequest('personal', DateTime.utc(2026, 12, 1), null)));
    await moving;
    expect(controller.state.window!.start, DateTime.utc(2026, 12, 1));
  });

  test('필터 변경 후 이전 필터의 늦은 응답을 사용하지 않는다', () async {
    final source = FakeCalendarDataSource();
    final gate = Completer<CalendarPeriod>();
    source.loader = (request) => request.paymentMethodId == null && request.anchorDate == DateTime.utc(2026, 12, 1) ? gate.future : Future.value(monthly(request));
    final controller = CalendarController(ledgerId: 'personal', dataSource: source, clock: () => DateTime(2026, 11, 20));
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.selectCard('cash');
    gate.complete(monthly(CalendarRequest('personal', DateTime.utc(2026, 12, 1), null)));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.selectedCardId, 'cash');
    expect(controller.state.nextPeriod?.paymentMethodId, 'cash');
  });

  test('카드 이동은 서버가 제공한 사이클과 기준 날짜를 사용한다', () async {
    final source = FakeCalendarDataSource();
    source.loader = (request) async {
      final day = request.anchorDate;
      if (request.paymentMethodId == null) return monthly(request);
      if (day.isBefore(DateTime.utc(2026, 10, 13))) return CalendarPeriod.fromJson(calendarJson(start: '2026-09-13', end: '2026-10-12', previous: '2026-09-12', next: '2026-10-13', card: 'chase'));
      if (day.isBefore(DateTime.utc(2026, 11, 13))) return CalendarPeriod.fromJson(calendarJson(start: '2026-10-13', end: '2026-11-12', previous: '2026-10-12', next: '2026-11-13', card: 'chase'));
      return CalendarPeriod.fromJson(calendarJson(start: '2026-11-13', end: '2026-12-12', previous: '2026-11-12', next: '2026-12-13', card: 'chase'));
    };
    final controller = CalendarController(ledgerId: 'personal', dataSource: source, clock: () => DateTime(2026, 10, 20));
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.selectCard('chase');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.nextPeriod!.window.start, DateTime.utc(2026, 11, 13));
    await controller.nextPeriod();
    expect(controller.state.window!.start, DateTime.utc(2026, 11, 13));
    expect(source.requests.where((request) => request.paymentMethodId == 'chase' && request.anchorDate == DateTime.utc(2026, 11, 13)).length, 1);
  });

  test('새로고침하면 주변 캐시도 다시 조회한다', () async {
    final source = FakeCalendarDataSource()..loader = (request) async => monthly(request);
    final controller = CalendarController(ledgerId: 'personal', dataSource: source, clock: () => DateTime(2026, 11, 20));
    addTearDown(controller.dispose);
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(source.requests.length, 3);
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(source.requests.length, 6);
  });
}
