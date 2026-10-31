import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/calendar/calendar.dart';

import 'support/calendar_fixtures.dart';

void main() {
  final window = CalendarWindow.containing(DateTime(2026, 10, 20));

  Map<DateTime, CalendarDay> project({
    String? selectedCardId,
    List<CalendarPaymentMethod>? methods,
    List<CalendarTransaction> transactions = const [],
    List<CalendarIncome> income = const [],
    List<CalendarNote> notes = const [],
  }) => buildCalendarDays(
    ledgerId: 'personal',
    window: window,
    paymentMethods: methods ?? testPaymentMethods(),
    transactions: transactions,
    income: income,
    notes: notes,
    selectedCardId: selectedCardId,
  );

  test(
    'All includes all methods; dots use saved colors and combine purchases',
    () {
      final day = project(
        transactions: [
          testTransaction(id: 'chase-2'),
          testTransaction(id: 'cash', methodId: 'cash'),
          testTransaction(id: 'chase-1'),
          testTransaction(id: 'amex', methodId: 'amex'),
        ],
      )[DateTime.utc(2026, 10, 20)]!;
      expect(day.transactions, hasLength(4));
      expect(day.dots.map((dot) => dot.paymentMethodId), [
        'amex',
        'cash',
        'chase',
      ]);
      expect(day.dots.map((dot) => dot.color), [
        '#AB3412',
        '#FCA05A',
        '#1234AB',
      ]);
      expect(day.dots.last.transactionCount, 2);
      expect(day.dots.last.label, 'Chase');
      expect(day.spendingCents, 2600); // Already includes tax/tip exactly once.
    },
  );

  test(
    'card selection filters transactions but preserves other daily events',
    () {
      final day = project(
        selectedCardId: 'chase',
        transactions: [
          testTransaction(),
          testTransaction(id: 'other', methodId: 'amex'),
        ],
        income: [testIncome(paymentMethodId: 'amex')],
        notes: [testNote()],
      )[DateTime.utc(2026, 10, 20)]!;
      expect(day.transactions.single.paymentMethodId, 'chase');
      expect(day.dots.single.color, '#1234AB');
      expect(day.income.single.paymentMethodId, 'amex');
      expect(day.closingCards.single.id, 'amex');
      expect(day.note!.content, 'Day note');
      expect(day.transactions.single.memo, 'Transaction memo');
    },
  );

  test(
    'income uses display date and only received income contributes to totals',
    () {
      final days = project(
        income: [
          testIncome(),
          testIncome(status: 'received', amountCents: 20000),
        ],
      );
      final day = days[DateTime.utc(2026, 10, 20)]!;
      expect(day.income, hasLength(2));
      expect(day.receivedIncomeCents, 20000);
      expect(day.income.first.expectedDate, DateTime.utc(2026, 10, 21));
      expect(days[DateTime.utc(2026, 10, 21)]!.income, isEmpty);
      expect(day.dots, isEmpty); // Income/notes/closings do not create dots.
    },
  );

  test('range and ledger boundaries exclude unrelated entries', () {
    final days = project(
      transactions: [
        testTransaction(id: 'before', date: '2026-09-30'),
        testTransaction(id: 'after', date: '2026-11-01'),
        testTransaction(id: 'other-ledger', ledgerId: 'other'),
        testTransaction(id: 'last', date: '2026-10-31'),
      ],
      income: [testIncome(date: '2026-11-01')],
      notes: [
        testNote(ledgerId: 'other'),
        testNote(date: '2026-11-01'),
      ],
    );
    expect(days, hasLength(31));
    expect(days.values.expand((day) => day.transactions).single.id, 'last');
    expect(days.values.expand((day) => day.income), isEmpty);
    expect(days.values.where((day) => day.note != null), isEmpty);
    expect(days[DateTime.utc(2026, 10, 1)]!.transactions, isEmpty);
  });

  test('boundary purchases belong to exactly one adjacent card cycle', () {
    final current = CalendarWindow.containing(
      DateTime(2026, 10, 20),
      closingDay: 12,
    );
    final next = current.shifted(1, closingDay: 12);
    final transactions = [
      testTransaction(id: 'closing', date: '2026-11-12'),
      testTransaction(id: 'next-start', date: '2026-11-13'),
    ];
    Map<DateTime, CalendarDay> cycle(CalendarWindow range) => buildCalendarDays(
      ledgerId: 'personal',
      window: range,
      selectedCardId: 'chase',
      paymentMethods: testPaymentMethods(),
      transactions: transactions,
      income: [],
      notes: [],
    );
    expect(
      cycle(current).values.expand((d) => d.transactions).single.id,
      'closing',
    );
    expect(
      cycle(next).values.expand((d) => d.transactions).single.id,
      'next-start',
    );
  });

  test(
    'closing dates clamp per card and include all cards on the same date',
    () {
      final days = buildCalendarDays(
        ledgerId: 'personal',
        window: CalendarWindow.containing(DateTime(2024, 2)),
        paymentMethods: [
          for (final closingDay in [29, 30, 31])
            CalendarPaymentMethod(
              id: '$closingDay',
              name: '$closingDay',
              type: 'credit',
              closingDay: closingDay,
              color: '#123456',
            ),
        ],
        transactions: [],
        income: [],
        notes: [],
      );
      expect(days[DateTime.utc(2024, 2, 29)]!.closingCards, hasLength(3));
      expect(days[DateTime.utc(2024, 2, 28)]!.closingCards, isEmpty);
    },
  );

  test(
    'unknown methods retain transactions and expose fallback dot metadata',
    () {
      final day = project(
        transactions: [testTransaction(methodId: 'missing')],
      )[DateTime.utc(2026, 10, 20)]!;
      expect(day.transactions, hasLength(1));
      expect(day.dots.single.paymentMethodId, 'missing');
      expect(day.dots.single.color, isNull);
      expect(day.dots.single.label, 'Unknown payment method');
    },
  );

  test('negative refunds are retained; blank notes are omitted', () {
    final day = project(
      transactions: [testTransaction(totalCents: -500)],
      notes: [testNote(content: '  ')],
    )[DateTime.utc(2026, 10, 20)]!;
    expect(day.spendingCents, -500);
    expect(day.dots.single.transactionCount, 1);
    expect(day.note, isNull);
  });

  test('API models retain transaction, income, and note detail immutably', () {
    final day = project(
      transactions: [testTransaction()],
      income: [testIncome(status: 'received')],
      notes: [testNote()],
    )[DateTime.utc(2026, 10, 20)]!;
    final transaction = day.transactions.single;
    expect(transaction.merchant, 'Test Cafe');
    expect(transaction.items.single.name, 'Coffee');
    expect(transaction.items.single.categoryId, 'dining');
    expect(transaction.items.single.amountCents, 500);
    expect(transaction.taxCents, 50);
    expect(transaction.tipCents, 100);
    expect(transaction.source, 'manual');
    expect(day.income.single.fromName, 'Employer');
    expect(day.income.single.receivedAt, DateTime.utc(2026, 10, 20));
    expect(day.note!.ledgerId, 'personal');
    expect(() => day.transactions.clear(), throwsUnsupportedError);
    expect(() => transaction.items.clear(), throwsUnsupportedError);
    expect(() => day.dots.clear(), throwsUnsupportedError);
  });
}
