import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/calendar/calendar.dart';

import 'support/calendar_fixtures.dart';

void main() {
  late FakeCalendarDataSource source;
  late CalendarController controller;
  setUp(() {
    source = FakeCalendarDataSource();
    controller = CalendarController(
      ledgerId: 'personal',
      dataSource: source,
      clock: () => DateTime(2026, 10, 20),
    );
  });
  tearDown(() => controller.dispose());

  test(
    'one request loads server period; day selection makes no request',
    () async {
      expect(controller.state.window, isNull);
      await controller.refresh();
      expect(source.requests.single.anchorDate, DateTime.utc(2026, 10, 20));
      expect(source.requests.single.ledgerId, 'personal');
      expect(controller.state.days.length, 31);
      controller.selectDate(DateTime(2026, 10, 6));
      expect(controller.state.selectedDay!.date, DateTime.utc(2026, 10, 6));
      expect(source.requests.length, 1);
    },
  );

  test('card switch sends highlighted date and uses server cycle', () async {
    await controller.refresh();
    source.response = CalendarPeriod.fromJson(
      calendarJson(
        start: '2026-10-13',
        end: '2026-11-12',
        previous: '2026-10-12',
        next: '2026-11-13',
        card: 'chase',
      ),
    );
    await controller.selectCard('chase');
    expect(source.requests.last.paymentMethodId, 'chase');
    expect(source.requests.last.anchorDate, DateTime.utc(2026, 10, 20));
    expect(controller.state.window!.start, DateTime.utc(2026, 10, 13));
    expect(controller.state.selectedDate, DateTime.utc(2026, 10, 20));
    source.response = CalendarPeriod.fromJson(calendarJson());
    await controller.selectCard(null);
    expect(source.requests.last.paymentMethodId, isNull);
  });

  test(
    'next and previous send server anchors; destination selects first day',
    () async {
      await controller.refresh();
      source.response = CalendarPeriod.fromJson(
        calendarJson(
          start: '2026-11-01',
          end: '2026-11-30',
          previous: '2026-10-31',
          next: '2026-12-01',
        ),
      );
      await controller.nextPeriod();
      expect(source.requests.last.anchorDate, DateTime.utc(2026, 11, 1));
      expect(controller.state.selectedDate, DateTime.utc(2026, 11, 1));
      source.response = CalendarPeriod.fromJson(calendarJson());
      await controller.previousPeriod();
      expect(source.requests.last.anchorDate, DateTime.utc(2026, 10, 31));
      expect(controller.state.selectedDate, DateTime.utc(2026, 10, 20));
    },
  );

  test(
    'date picker and today use server or loaded dates as appropriate',
    () async {
      await controller.refresh();
      await controller.jumpToDate(DateTime(2026, 10, 10));
      await controller.goToToday();
      expect(source.requests.length, 1);
      source.response = CalendarPeriod.fromJson(
        calendarJson(start: '2026-11-01', end: '2026-11-30'),
      );
      await controller.jumpToDate(DateTime(2026, 11, 8));
      expect(source.requests.last.anchorDate, DateTime.utc(2026, 11, 8));
      expect(controller.state.selectedDate, DateTime.utc(2026, 11, 8));
      expect(
        () => controller.selectDate(DateTime(2026, 12, 1)),
        throwsArgumentError,
      );
    },
  );

  test(
    'stale successful response cannot overwrite newer card selection',
    () async {
      final first = Completer<CalendarPeriod>();
      source.loader = (request) => source.requests.length == 1
          ? first.future
          : Future.value(source.response);
      final old = controller.refresh();
      source.response = CalendarPeriod.fromJson(calendarJson(card: 'chase'));
      await controller.selectCard('chase');
      first.complete(CalendarPeriod.fromJson(calendarJson()));
      await old;
      expect(controller.state.selectedCardId, 'chase');
    },
  );

  test('stale error cannot replace a newer successful response', () async {
    final first = Completer<CalendarPeriod>();
    source.loader = (_) => source.requests.length == 1
        ? first.future
        : Future.value(source.response);
    final old = controller.refresh();
    await controller.refresh();
    first.completeError(StateError('old failure'));
    await old;
    expect(controller.state.error, isNull);
    expect(controller.state.days, isNotEmpty);
  });

  test(
    'failed card selection is explicit; retry and choosing All recover',
    () async {
      await controller.refresh();
      source.loader = (_) => Future.error(StateError('card removed'));
      await controller.selectCard('removed');
      expect(controller.state.error, isNotNull);
      expect(controller.state.days, isEmpty);
      expect(controller.state.selectedCardId, 'removed');
      await controller.refresh();
      expect(source.requests.last.paymentMethodId, 'removed');
      source.loader = null;
      await controller.selectCard(null);
      expect(controller.state.error, isNull);
    },
  );

  test('pending navigation is not repeated using obsolete anchors', () async {
    await controller.refresh();
    final gate = Completer<CalendarPeriod>();
    source.loader = (_) => gate.future;
    final next = controller.nextPeriod();
    await controller.nextPeriod();
    expect(source.requests.length, 2);
    expect(controller.state.days, isEmpty);
    gate.complete(source.response);
    await next;
  });

  test(
    'note save captures selected date, reloads once, and supports clearing',
    () async {
      await controller.refresh();
      controller.selectDate(DateTime(2026, 10, 6));
      expect(await controller.saveSelectedNote('Remember'), isTrue);
      expect(source.writes.last.date, DateTime.utc(2026, 10, 6));
      expect(source.writes.last.content, 'Remember');
      expect(source.requests.length, 2);
      expect(await controller.saveSelectedNote(''), isTrue);
      expect(source.writes.last.content, '');
    },
  );

  test('failed note save retains loaded data and does not reload', () async {
    await controller.refresh();
    source.saveError = StateError('write failed');
    expect(await controller.saveSelectedNote('draft'), isFalse);
    expect(controller.state.noteError, isNotNull);
    expect(controller.state.days.length, 31);
    expect(source.requests.length, 1);
  });

  test('successful save remains successful when reload fails', () async {
    await controller.refresh();
    source.loader = (_) => Future.error(StateError('read failed'));
    expect(await controller.saveSelectedNote('saved'), isTrue);
    expect(controller.state.noteError, isNull);
    expect(controller.state.error, isNotNull);
  });

  test(
    'save during navigation retains write date and reloads current anchor',
    () async {
      await controller.refresh();
      source.saveGate = Completer<void>();
      final save = controller.saveSelectedNote('draft');
      await expectLater(
        controller.saveSelectedNote('duplicate'),
        throwsStateError,
      );
      source.response = CalendarPeriod.fromJson(
        calendarJson(start: '2026-11-01', end: '2026-11-30'),
      );
      await controller.jumpToDate(DateTime(2026, 11, 6));
      source.saveGate!.complete();
      expect(await save, isTrue);
      expect(source.writes.single.date, DateTime.utc(2026, 10, 20));
      expect(source.requests.last.anchorDate, DateTime.utc(2026, 11, 6));
    },
  );

  test(
    'stream emits loading and success; disposal ignores pending work',
    () async {
      final states = <CalendarState>[];
      final subscription = controller.changes.listen(states.add);
      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(states.map((s) => s.isLoading), [true, false]);
      final gate = Completer<CalendarPeriod>();
      source.loader = (_) => gate.future;
      final pending = controller.refresh();
      controller.dispose();
      gate.complete(source.response);
      await pending;
      expect(
        () => controller.selectDate(DateTime(2026, 10, 6)),
        throwsStateError,
      );
      await subscription.cancel();
    },
  );
}
