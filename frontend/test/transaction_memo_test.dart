import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/data/transactions/transaction_repository.dart';
import 'package:spending_tracker/home/widgets/home_note_sheet.dart';

void main() {
  test('거래 ID와 메모만 인증된 PATCH로 보낸다', () async {
    final requests = <http.Request>[];
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((request) async {
      requests.add(request);
      return http.Response('{"id":"transaction-2","memo":null}', 200);
    }));
    addTearDown(api.close);
    await TransactionRepository(api).updateMemo('ledger', 'transaction-2', '');
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/ledgers/ledger/transactions/transaction-2/memo');
    expect(requests.single.headers['authorization'], 'Bearer token');
    expect(jsonDecode(requests.single.body), {'memo': ''});
  });

  testWidgets('실패하면 입력을 유지하고 재시도 후에만 닫는다', (tester) async {
    var calls = 0;
    final saved = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showModalBottomSheet<String>(context: context, builder: (_) => HomeNoteSheet(date: DateTime(2026, 10, 20), initialText: 'Old', onSave: (text) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      saved.add(text);
    })), child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('home-note-input')), 'New note');
    await tester.tap(find.byKey(const Key('home-note-save')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to save your note. Please try again.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('home-note-input'))).controller!.text, 'New note');
    await tester.tap(find.byKey(const Key('home-note-save')));
    await tester.pumpAndSettle();
    expect(saved, ['New note']);
    expect(find.byKey(const Key('home-note-sheet')), findsNothing);
  });
}
