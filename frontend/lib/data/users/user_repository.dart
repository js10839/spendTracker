import '../../core/api_client.dart';

/// 앱 사용자 초기화를 화면에서 분리한다.
abstract class UserRepository {
  static UserRepository instance = const UnconfiguredUserRepository();

  /// 인증된 사용자의 앱 프로필과 기본 데이터를 초기화한다.
  Future<String> bootstrap();
}

/// API 주소가 없는 실행 환경에서 설정 누락을 알린다.
class UnconfiguredUserRepository implements UserRepository {
  const UnconfiguredUserRepository();

  @override
  Future<String> bootstrap() async => throw StateError('API is not configured');
}

/// FastAPI의 사용자 초기화 API를 호출한다.
class ApiUserRepository implements UserRepository {
  const ApiUserRepository(this.api);
  final ApiClient api;

  @override
  Future<String> bootstrap() async {
    final body = await api.post('/users/me/bootstrap');
    final userId = body['user_id'];
    if (userId is! String || userId.isEmpty) throw const FormatException('Missing user_id');
    return userId;
  }
}
