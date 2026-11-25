import '../../api/api_client.dart';

/// 서버에 등록된 카테고리의 표시 이름을 조회한다.
class CategoryRepository {
  const CategoryRepository(this.api);
  final ApiClient api;

  /// 거래 품목의 카테고리 ID를 표시 이름으로 연결한다.
  Future<Map<String, String>> listNames() async {
    final json = await api.getJson(['categories']);
    if (json is! List) throw const FormatException('Expected a category list');
    return {for (final item in json) (item as Map<String, dynamic>)['id'] as String: item['name'] as String};
  }
}
