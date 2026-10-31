import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar.dart';

void main() {
  final cycle = CalendarWindow.containing(
    DateTime(2026, 10, 20),
    closingDay: 12,
  );
  final paymentMethods = [
    {
      'id': 'chase',
      'name': 'Chase',
      'type': 'credit',
      'closing_day': 12,
      'color': '#1234AB',
    },
    {
      'id': 'amex',
      'name': 'Amex',
      'type': 'credit',
      'closing_day': 20,
      'color': '#AB3412',
    },
  ];
  Map<String, Object?> transaction(String id, String method) => {
    'id': id,
    'ledger_id': 'personal',
    'payment_method_id': method,
    'merchant': 'Cafe',
    'transacted_at': '2026-10-20',
    'memo': 'Purchase memo',
    'source': 'manual',
    'total_cents': 650,
    'tax_cents': 50,
    'tip_cents': 100,
    'items': [
      {
        'id': 'item-$id',
        'name': 'Coffee',
        'category_id': 'dining',
        'amount_cents': 500,
      },
    ],
  };
  final income = {
    'status': 'planned',
    'income_type': 'paycheck',
    'amount_cents': 10000,
    'display_date': '2026-10-20',
    'expected_date': '2026-10-21',
    'income_source_id': 'salary',
    'income_record_id': null,
    'payment_method_id': null,
    'from_name': 'Employer',
    'received_at': null,
    'memo': null,
  };
  Map<String, Object?> note(String content) => {
    'id': 'note',
    'ledger_id': 'personal',
    'note_date': '2026-10-20',
    'content': content,
  };

  HttpCalendarDataSource source(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final transport = MockClient(handler);
    final api = ApiClient(
      baseUrl: Uri.parse('https://backend.example.com'),
      accessToken: () => 'manual-test-token',
      client: transport,
    );
    addTearDown(api.close);
    addTearDown(transport.close);
    return HttpCalendarDataSource(api);
  }

  http.Response jsonResponse(Object? value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json'},
  );

  test('wallet GET reads card colors and closing days', () async {
    final adapter = source((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/users/me/payment-methods');
      expect(request.url.queryParameters, isEmpty);
      expect(request.headers['Authorization'], 'Bearer manual-test-token');
      return jsonResponse(paymentMethods);
    });
    final methods = await adapter.loadPaymentMethods();
    expect(methods.first.id, 'chase');
    expect(methods.first.color, '#1234AB');
    expect(methods.first.closingDay, 12);
  });

  test(
    'transaction GET passes inclusive cycle dates and optional card filter',
    () async {
      final requests = <http.Request>[];
      final adapter = source((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.url.path, '/ledgers/personal/transactions');
        return jsonResponse([transaction('purchase', 'chase')]);
      });
      final transactions = await adapter.loadTransactions(
        ledgerId: 'personal',
        window: cycle,
        paymentMethodId: 'chase',
      );
      expect(requests.last.url.queryParameters, {
        'start_date': '2026-10-13',
        'end_date': '2026-11-12',
        'payment_method_id': 'chase',
      });
      expect(transactions.single.totalCents, 650);
      expect(transactions.single.items.single.name, 'Coffee');
      await adapter.loadTransactions(ledgerId: 'personal', window: cycle);
      expect(requests.last.url.queryParameters, cycle.queryParameters);
    },
  );

  test(
    'income and notes GETs use the whole range without card filtering',
    () async {
      final adapter = source((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters, cycle.queryParameters);
        return switch (request.url.path) {
          '/ledgers/personal/income-calendar' => jsonResponse([income]),
          '/ledgers/personal/day-notes' => jsonResponse([note('Reminder')]),
          _ => throw StateError('Unexpected request'),
        };
      });
      final entries = await adapter.loadIncome(
        ledgerId: 'personal',
        window: cycle,
      );
      expect(entries.single.displayDate, DateTime.utc(2026, 10, 20));
      expect(entries.single.expectedDate, DateTime.utc(2026, 10, 21));
      expect(entries.single.status, 'planned');
      final notes = await adapter.loadNotes(
        ledgerId: 'personal',
        window: cycle,
      );
      expect(notes.single.content, 'Reminder');
    },
  );

  test(
    'note PUT sends content and decodes saved note or null on clear',
    () async {
      final adapter = source((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/ledgers/personal/day-notes/2026-10-20');
        expect(request.url.queryParameters, isEmpty);
        final content = (jsonDecode(request.body) as Map)['content'] as String;
        return jsonResponse(content.isEmpty ? null : note(content));
      });
      final saved = await adapter.saveNote(
        ledgerId: 'personal',
        date: DateTime(2026, 10, 20, 17),
        content: 'Hello\nWorld',
      );
      expect(saved!.content, 'Hello\nWorld');
      expect(
        await adapter.saveNote(
          ledgerId: 'personal',
          date: DateTime(2026, 10, 20),
          content: '',
        ),
        isNull,
      );
    },
  );

  test('invalid response shapes or fields surface schema errors', () async {
    for (final body in <Object?>[
      null,
      {'items': []},
      [1],
      [
        {'id': 'missing-fields'},
      ],
      [
        {
          'id': 'x',
          'name': 'X',
          'type': 'credit',
          'closing_day': 99,
          'color': '#123456',
        },
      ],
    ]) {
      final adapter = source((_) async => jsonResponse(body));
      await expectLater(adapter.loadPaymentMethods(), throwsFormatException);
    }
    final adapter = source((_) async => jsonResponse([]));
    await expectLater(
      adapter.saveNote(
        ledgerId: 'personal',
        date: DateTime(2026, 10, 20),
        content: 'Note',
      ),
      throwsFormatException,
    );
  });

  test('HTTP errors propagate to calendar state for retry', () async {
    var fail = true;
    final adapter = source((request) async {
      if (request.url.path == '/users/me/payment-methods') {
        return jsonResponse(paymentMethods);
      }
      if (request.url.path.endsWith('income-calendar') && fail) {
        return http.Response('{"detail":"Temporarily unavailable"}', 503);
      }
      return jsonResponse([]);
    });
    final controller = CalendarController(
      ledgerId: 'personal',
      dataSource: adapter,
      clock: () => DateTime(2026, 10, 20),
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.error, isA<ApiException>());
    expect(controller.state.days, isEmpty);
    fail = false;
    await controller.refresh();
    expect(controller.state.error, isNull);
    expect(controller.state.days, hasLength(31));
  });

  test(
    'controller selects a card, reads local details, and saves through HTTP',
    () async {
      final requests = <http.Request>[];
      Map<String, Object?>? savedNote;
      final adapter = source((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer manual-test-token');
        if (request.url.path == '/users/me/payment-methods') {
          return jsonResponse(paymentMethods);
        }
        if (request.method == 'PUT') {
          final content =
              (jsonDecode(request.body) as Map)['content'] as String;
          savedNote = content.isEmpty ? null : note(content);
          return jsonResponse(savedNote);
        }
        final range = request.url.queryParameters;
        expect(range['start_date'], anyOf('2026-10-01', '2026-10-13'));
        expect(range['end_date'], anyOf('2026-10-31', '2026-11-12'));
        return switch (request.url.path) {
          '/ledgers/personal/transactions' => jsonResponse([
            transaction('chase-purchase', 'chase'),
            if (range['payment_method_id'] == null)
              transaction('amex-purchase', 'amex'),
          ]),
          '/ledgers/personal/income-calendar' => jsonResponse([income]),
          '/ledgers/personal/day-notes' => jsonResponse([?savedNote]),
          _ => throw StateError('Unexpected request'),
        };
      });
      final controller = CalendarController(
        ledgerId: 'personal',
        dataSource: adapter,
        clock: () => DateTime(2026, 10, 20),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.state.selectedDay!.transactions, hasLength(2));
      await controller.selectCard('chase');
      final day = controller.state.selectedDay!;
      expect(day.transactions.single.id, 'chase-purchase');
      expect(day.dots.single.color, '#1234AB');
      expect(day.closingCards.single.id, 'amex');
      expect(day.income.single.status, 'planned');
      final count = requests.length;
      controller.selectDate(DateTime(2026, 10, 21));
      controller.selectDate(DateTime(2026, 10, 20));
      expect(requests, hasLength(count));
      expect(await controller.saveSelectedNote('Remember this'), isTrue);
      expect(controller.state.selectedDay!.note!.content, 'Remember this');
      expect(await controller.saveSelectedNote(''), isTrue);
      expect(controller.state.selectedDay!.note, isNull);
    },
  );
}
