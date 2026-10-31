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
      clock: () => DateTime(2026, 10, 20, 14),
    );
  });
  tearDown(() => controller.dispose());

  test(
    'initializes All and loads the entire window for all three datasets',
    () async {
      expect(controller.state.selectedCardId, isNull);
      expect(controller.state.selectedDate, DateTime.utc(2026, 10, 20));
      expect(source.methodLoads, 0);
      await controller.refresh();
      expect(controller.state.cards.map((card) => card.id), ['chase', 'amex']);
      expect(controller.state.days, hasLength(31));
      final transactionRequest = source.transactionRequests.single;
      expect(transactionRequest.paymentMethodId, isNull);
      for (final request in [
        transactionRequest,
        source.incomeRequests.single,
        source.noteRequests.single,
      ]) {
        expect(request.ledgerId, 'personal');
        expect(request.window.queryParameters, {
          'start_date': '2026-10-01',
          'end_date': '2026-10-31',
        });
      }
      expect(controller.state.error, isNull);
      expect(controller.state.isLoading, isFalse);
      expect(() => controller.state.days.clear(), throwsUnsupportedError);
      expect(
        () => controller.state.paymentMethods.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'selecting a card changes range and filters only transactions',
    () async {
      source.transactions = [
        testTransaction(),
        testTransaction(id: 'amex', methodId: 'amex'),
      ];
      source.income = [testIncome(paymentMethodId: 'amex')];
      source.notes = [testNote()];
      await controller.refresh();
      await controller.selectCard('chase');
      expect(controller.state.window.queryParameters, {
        'start_date': '2026-10-13',
        'end_date': '2026-11-12',
      });
      expect(source.transactionRequests.last.paymentMethodId, 'chase');
      expect(
        source.incomeRequests.last.window.start,
        controller.state.window.start,
      );
      expect(
        source.noteRequests.last.window.endInclusive,
        controller.state.window.endInclusive,
      );
      final day = controller.state.selectedDay!;
      expect(day.transactions.single.paymentMethodId, 'chase');
      expect(day.dots.single.color, '#1234AB');
      expect(day.income.single.paymentMethodId, 'amex');
      expect(day.closingCards.single.id, 'amex');
      expect(day.note!.content, 'Day note');
      await controller.selectCard(null);
      expect(controller.state.window.start, DateTime.utc(2026, 10));
      expect(source.transactionRequests.last.paymentMethodId, isNull);
      expect(controller.state.selectedDay!.transactions, hasLength(2));
      expect(() => controller.selectCard('cash'), throwsArgumentError);
      expect(() => controller.selectCard('unregistered'), throwsArgumentError);
    },
  );

  test('day selection is local and retains selection while loading', () async {
    await controller.refresh();
    controller.selectDate(DateTime(2026, 10, 25, 18));
    expect(controller.state.selectedDate, DateTime.utc(2026, 10, 25));
    expect(controller.state.selectedDay!.transactions, isEmpty);
    await controller.jumpToDate(DateTime(2026, 10, 26));
    expect(source.methodLoads, 1);
    expect(source.transactionRequests, hasLength(1));
    expect(source.incomeRequests, hasLength(1));
    expect(source.noteRequests, hasLength(1));
    expect(
      () => controller.selectDate(DateTime(2026, 11)),
      throwsArgumentError,
    );

    final pending = Completer<List<CalendarTransaction>>();
    final started = Completer<void>();
    source.transactionsLoader = (_) {
      started.complete();
      return pending.future;
    };
    final refreshing = controller.refresh();
    await started.future;
    controller.selectDate(DateTime(2026, 10, 27));
    pending.complete([]);
    await refreshing;
    expect(controller.state.selectedDate, DateTime.utc(2026, 10, 27));
  });

  test(
    'previous/next, date picker, and Today use the selected calendar mode',
    () async {
      await controller.refresh();
      await controller.nextPeriod();
      expect(controller.state.window.start, DateTime.utc(2026, 11));
      expect(controller.state.selectedDate, DateTime.utc(2026, 11));
      await controller.previousPeriod();
      expect(controller.state.selectedDate, DateTime.utc(2026, 10, 20));
      await controller.jumpToDate(DateTime(2027, 1, 15));
      expect(controller.state.window.start, DateTime.utc(2027, 1));
      await controller.selectCard('chase');
      expect(controller.state.window.start, DateTime.utc(2027, 1, 13));
      await controller.previousPeriod();
      expect(controller.state.window.start, DateTime.utc(2026, 12, 13));
      expect(controller.state.selectedDate, DateTime.utc(2026, 12, 13));
      await controller.nextPeriod();
      expect(controller.state.window.start, DateTime.utc(2027, 1, 13));
      await controller.goToToday();
      expect(controller.state.window.start, DateTime.utc(2026, 10, 13));
      expect(controller.state.selectedDate, DateTime.utc(2026, 10, 20));
      final requests = source.transactionRequests.length;
      await controller.goToToday();
      expect(source.transactionRequests, hasLength(requests));
    },
  );

  test('month-end cycle navigation never drifts through February', () async {
    source.methods = [
      CalendarPaymentMethod(
        id: 'month-end',
        name: 'Month end',
        type: 'credit',
        closingDay: 31,
        color: '#ABCDEF',
      ),
    ];
    await controller.refresh();
    await controller.selectCard('month-end');
    await controller.jumpToDate(DateTime(2024, 2, 29));
    expect(controller.state.window.start, DateTime.utc(2024, 2));
    await controller.nextPeriod();
    expect(controller.state.window.start, DateTime.utc(2024, 3));
    await controller.previousPeriod();
    expect(controller.state.window.endInclusive, DateTime.utc(2024, 2, 29));
  });

  test('loads transactions, income, and notes concurrently', () async {
    final pending = Completer<List<CalendarTransaction>>();
    final started = Completer<void>();
    source.transactionsLoader = (_) {
      started.complete();
      return pending.future;
    };
    final loading = controller.refresh();
    await started.future;
    expect(source.incomeRequests, hasLength(1));
    expect(source.noteRequests, hasLength(1));
    expect(controller.state.isLoading, isTrue);
    expect(controller.state.days, isEmpty);
    pending.complete([testTransaction()]);
    await loading;
    expect(controller.state.selectedDay!.transactions, hasLength(1));
  });

  test('late period response cannot replace a newer period', () async {
    await controller.refresh();
    final old = Completer<List<CalendarTransaction>>();
    final started = Completer<void>();
    source.transactionsLoader = (request) {
      if (request.window.start.month == 11) {
        started.complete();
        return old.future;
      }
      return Future.value([testTransaction(id: 'new', date: '2026-12-01')]);
    };
    final oldLoad = controller.nextPeriod();
    await started.future;
    expect(controller.state.days, isEmpty);
    await controller.nextPeriod();
    old.complete([testTransaction(id: 'old', date: '2026-11-01')]);
    await oldLoad;
    expect(controller.state.window.start, DateTime.utc(2026, 12));
    expect(controller.state.selectedDay!.transactions.single.id, 'new');
    expect(controller.state.error, isNull);
  });

  test('late card response or error cannot replace a newer card', () async {
    await controller.refresh();
    final old = Completer<List<CalendarTransaction>>();
    final started = Completer<void>();
    source.transactionsLoader = (request) {
      if (request.paymentMethodId == 'chase') {
        started.complete();
        return old.future;
      }
      return Future.value([testTransaction(methodId: 'amex')]);
    };
    final oldLoad = controller.selectCard('chase');
    await started.future;
    await controller.selectCard('amex');
    old.completeError(StateError('Old request failed'));
    await oldLoad;
    expect(controller.state.selectedCardId, 'amex');
    expect(controller.state.window.endInclusive, DateTime.utc(2026, 10, 20));
    expect(
      controller.state.selectedDay!.transactions.single.paymentMethodId,
      'amex',
    );
    expect(controller.state.error, isNull);
  });

  test(
    'late wallet metadata cannot overwrite a newer navigation request',
    () async {
      await controller.refresh();
      final old = Completer<List<CalendarPaymentMethod>>();
      var calls = 0;
      source.methodsLoader = () =>
          calls++ == 0 ? old.future : Future.value(source.methods);
      final oldLoad = controller.refresh();
      await controller.nextPeriod();
      old.complete(testPaymentMethods());
      await oldLoad;
      expect(controller.state.window.start, DateTime.utc(2026, 11));
      expect(source.transactionRequests, hasLength(2));
    },
  );

  test('metadata refresh updates colors/closing days and removed cards fall back to All', () async {
    source.transactions = [testTransaction()];
    await controller.refresh();
    await controller.selectCard('chase');
    source.methods = [
      CalendarPaymentMethod(
        id: 'chase',
        name: 'Chase',
        type: 'credit',
        closingDay: 25,
        color: '#987654',
      ),
    ];
    await controller.refresh();
    expect(controller.state.window.start, DateTime.utc(2026, 9, 26));
    expect(controller.state.selectedDay!.dots.single.color, '#987654');
    source.methods = [];
    await controller.refresh();
    expect(controller.state.selectedCardId, isNull);
    expect(controller.state.window.start, DateTime.utc(2026, 10));
    expect(source.transactionRequests.last.paymentMethodId, isNull);
  });

  test(
    'wallet, income, and note failures are visible and can be retried',
    () async {
      source.methodsError = StateError('Wallet unavailable');
      await controller.refresh();
      expect(controller.state.error, same(source.methodsError));
      expect(controller.state.isLoading, isFalse);
      expect(source.transactionRequests, isEmpty);
      source.methodsError = null;
      source.incomeError = StateError('Income unavailable');
      await controller.refresh();
      expect(controller.state.error, same(source.incomeError));
      expect(controller.state.days, isEmpty);
      source.incomeError = null;
      source.notesError = StateError('Notes unavailable');
      await controller.refresh();
      expect(controller.state.error, same(source.notesError));
      source.notesError = null;
      await controller.refresh();
      expect(controller.state.error, isNull);
      expect(controller.state.days, hasLength(31));
    },
  );

  test('save and clear notes reload the window and keep transaction memos separate', () async {
    source.transactions = [testTransaction()];
    await controller.refresh();
    expect(await controller.saveSelectedNote('New note'), isTrue);
    expect(source.noteWrites.single.ledgerId, 'personal');
    expect(source.noteWrites.single.date, DateTime.utc(2026, 10, 20));
    expect(controller.state.selectedDay!.note!.content, 'New note');
    expect(
      controller.state.selectedDay!.transactions.single.memo,
      'Transaction memo',
    );
    expect(await controller.saveSelectedNote(''), isTrue);
    expect(controller.state.selectedDay!.note, isNull);
    expect(controller.state.isSavingNote, isFalse);
    expect(controller.state.noteError, isNull);
    expect(source.noteRequests, hasLength(3));
  });

  test(
    'failed note writes return false and can be retried with the same draft',
    () async {
      source.notes = [testNote(content: 'Original')];
      await controller.refresh();
      source.saveError = StateError('Save failed');
      expect(await controller.saveSelectedNote('Unsaved draft'), isFalse);
      expect(controller.state.noteError, same(source.saveError));
      expect(controller.state.selectedDay!.note!.content, 'Original');
      expect(controller.state.isSavingNote, isFalse);
      source.saveError = null;
      expect(await controller.saveSelectedNote('Unsaved draft'), isTrue);
      expect(controller.state.selectedDay!.note!.content, 'Unsaved draft');
      expect(controller.state.noteError, isNull);
    },
  );

  test('a pending note saves its original date despite navigation', () async {
    await controller.refresh();
    source.saveGate = Completer<void>();
    final saving = controller.saveSelectedNote('October note');
    expect(controller.state.isSavingNote, isTrue);
    await expectLater(
      controller.saveSelectedNote('Duplicate'),
      throwsStateError,
    );
    await controller.nextPeriod();
    source.saveGate!.complete();
    expect(await saving, isTrue);
    expect(source.noteWrites.single.date, DateTime.utc(2026, 10, 20));
    expect(controller.state.window.start, DateTime.utc(2026, 11));
    expect(controller.state.selectedDay!.note, isNull);
    await controller.previousPeriod();
    expect(controller.state.selectedDay!.note!.content, 'October note');
  });

  test(
    'successful note write is distinguished from subsequent reload failure',
    () async {
      await controller.refresh();
      source.notesError = StateError('Reload failed');
      expect(await controller.saveSelectedNote('Persisted'), isTrue);
      expect(source.notes.single.content, 'Persisted');
      expect(controller.state.noteError, isNull);
      expect(controller.state.error, same(source.notesError));
      expect(controller.state.isSavingNote, isFalse);
    },
  );

  test(
    'state stream exposes loading/ready states and closes on disposal',
    () async {
      final states = <CalendarState>[];
      final done = Completer<void>();
      controller.changes.listen(states.add, onDone: done.complete);
      await controller.refresh();
      controller.selectDate(DateTime(2026, 10, 21));
      controller.dispose();
      await done.future;
      expect(states.first.isLoading, isTrue);
      expect(states.last.selectedDate, DateTime.utc(2026, 10, 21));
      expect(states.last.isLoading, isFalse);
      expect(
        () => controller.selectDate(DateTime(2026, 10, 22)),
        throwsStateError,
      );
      await expectLater(controller.refresh(), throwsStateError);
    },
  );

  test('disposal ignores in-flight loads and note saves', () async {
    await controller.refresh();
    final old = Completer<List<CalendarTransaction>>();
    final started = Completer<void>();
    source.transactionsLoader = (_) {
      started.complete();
      return old.future;
    };
    final loading = controller.nextPeriod();
    await started.future;
    source.saveGate = Completer<void>();
    final saving = controller.saveSelectedNote('Pending');
    controller.dispose();
    final disposedState = controller.state;
    old.complete([]);
    source.saveGate!.complete();
    await loading;
    expect(await saving, isTrue);
    expect(controller.state, same(disposedState));
  });
}
