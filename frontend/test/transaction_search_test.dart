import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/data/transactions/transaction_repository.dart';

void main() {
  test('카드 사이클 범위와 결제수단을 검색 API에 전달한다', () async {
    late http.Request captured;
    final api = ApiClient(baseUrl: Uri.parse('https://example.com'), accessToken: () => 'token', client: MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'matched_dates': ['2026-11-01'], 'item_count': 1, 'store_count': 1, 'matched_items_total_cents': 125, 'items': [{'item_id': 'item', 'transaction_id': 'tx', 'name': 'Coffee', 'merchant': 'Cafe', 'category_id': 'cat', 'category_name': 'Dining', 'transacted_at': '2026-11-01', 'amount_cents': 125, 'matched_fields': ['item']}]}), 200);
    }));
    addTearDown(api.close);
    final result = await TransactionRepository(api).search('ledger', DateTime(2026, 10, 13), DateTime(2026, 11, 12), 'Coffee', 'cash');
    expect(captured.url.path, '/ledgers/ledger/transactions/search');
    expect(captured.url.queryParameters, {'start_date': '2026-10-13', 'end_date': '2026-11-12', 'query': 'Coffee', 'payment_method_id': 'cash'});
    expect(result.totalCents, 125);
    expect(result.dates, {DateTime.utc(2026, 11, 1)});
    expect(result.items.single.transactionId, 'tx');
  });
}
