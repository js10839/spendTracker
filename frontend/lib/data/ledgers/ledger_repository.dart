import '../../api/api_client.dart';

/// 접근 가능한 가계부의 서버 식별자와 이름이다.
class Ledger {
  const Ledger({required this.id, required this.name});
  final String id;
  final String name;
}

/// 현재 사용자가 접근 가능한 가계부를 조회한다.
class LedgerRepository {
  const LedgerRepository(this.api);
  final ApiClient api;

  /// 인증된 가계부 목록을 서버 응답 그대로 읽는다.
  Future<List<Ledger>> list() async {
    final json = await api.getJson(['ledgers']);
    if (json is! List) throw const FormatException('Expected a ledger list');
    return json.map((item) {
      if (item is! Map<String, dynamic> || item['id'] is! String || (item['id'] as String).isEmpty || item['name'] is! String) throw const FormatException('Invalid ledger');
      return Ledger(id: item['id'] as String, name: item['name'] as String);
    }).toList(growable: false);
  }
}
