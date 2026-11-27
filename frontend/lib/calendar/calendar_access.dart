import '../data/ledgers/ledger_repository.dart';
import '../data/categories/category_repository.dart';
import '../data/transactions/transaction_repository.dart';
import '../data/transactions/transaction_search.dart';
import 'calendar_controller.dart';
import 'calendar_data_source.dart';

/// 가계부 조회와 달력 컨트롤러 생성을 홈 화면에서 분리한다.
class CalendarAccess {
  const CalendarAccess({required this.ledgers, required this.dataSource});
  static CalendarAccess? instance;
  final LedgerRepository ledgers;
  final CalendarDataSource dataSource;

  /// 거래 품목의 카테고리 이름을 서버에서 조회한다.
  Future<Map<String, String>> loadCategoryNames() => CategoryRepository(ledgers.api).listNames();

  /// 홈 검색을 거래 저장소에 위임한다.
  Future<TransactionSearchResult> searchTransactions(String ledgerId, DateTime start, DateTime end, String query, String? paymentMethodId) => TransactionRepository(ledgers.api).search(ledgerId, start, end, query, paymentMethodId);

  /// 거래 메모 저장을 거래 저장소에 위임한다.
  Future<void> updateTransactionMemo(String ledgerId, String transactionId, String text) => TransactionRepository(ledgers.api).updateMemo(ledgerId, transactionId, text);

  /// 가계부를 조회한 뒤 현재 MVP의 단일 가계부 달력을 준비한다.
  Future<CalendarController> open() async {
    final available = await ledgers.list();
    // 공유 가계부 도입 시 선택 정책을 정하기 전에는 임의로 고르지 않는다.
    if (available.length != 1) throw StateError('Expected one accessible ledger');
    final controller = CalendarController(ledgerId: available.single.id, dataSource: dataSource);
    await controller.refresh();
    return controller;
  }
}
