import '../../api/api_client.dart';
import '../../calendar/calendar_dates.dart';
import 'transaction_search.dart';

/// 가계부 거래의 서버 저장을 담당한다.
class TransactionRepository {
  const TransactionRepository(this.api);
  final ApiClient api;

  /// 지정된 서버 기간과 결제수단의 품목을 검색한다.
  Future<TransactionSearchResult> search(String ledgerId, DateTime start, DateTime end, String query, String? paymentMethodId) async {
    final result = await api.getJson(['ledgers', ledgerId, 'transactions', 'search'], queryParameters: {
      'start_date': calendarDateKey(start), 'end_date': calendarDateKey(end), 'query': query,
      'payment_method_id': ?paymentMethodId,
    });
    if (result is! Map<String, dynamic>) throw const FormatException('Invalid transaction search response');
    return TransactionSearchResult.fromJson(result);
  }

  /// 거래의 메모만 저장하고 다른 거래 필드는 변경하지 않는다.
  Future<void> updateMemo(String ledgerId, String transactionId, String text) async {
    final result = await api.patchJson(['ledgers', ledgerId, 'transactions', transactionId, 'memo'], body: {'memo': text});
    if (result is! Map<String, dynamic> || result['id'] != transactionId || (result['memo'] != null && result['memo'] is! String)) {
      throw const FormatException('Invalid transaction memo response');
    }
  }
}
