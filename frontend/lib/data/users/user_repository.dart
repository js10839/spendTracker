import '../../core/api_client.dart';

/// 서버가 반환한 사용자와 가입 정보 입력 필요 여부다.
class UserBootstrapResult {
  const UserBootstrapResult({required this.userId, required this.onboardingRequired});
  final String userId;
  final bool onboardingRequired;
}

/// 앱 사용자 초기화를 화면에서 분리한다.
abstract class UserRepository {
  static UserRepository instance = const UnconfiguredUserRepository();

  /// 인증된 사용자의 앱 프로필과 기본 데이터를 초기화한다.
  Future<UserBootstrapResult> bootstrap();

  /// 저장하지 않은 무작위 표시 이름 후보를 조회한다.
  Future<String> getNicknameSuggestion();

  /// 확인한 표시 이름으로 가입 정보 입력을 완료한다.
  Future<void> completeOnboarding(String nickname);
}

/// API 주소가 없는 실행 환경에서 설정 누락을 알린다.
class UnconfiguredUserRepository implements UserRepository {
  const UnconfiguredUserRepository();

  @override
  Future<UserBootstrapResult> bootstrap() async => throw StateError('API is not configured');

  @override
  Future<String> getNicknameSuggestion() async => throw StateError('API is not configured');

  @override
  Future<void> completeOnboarding(String nickname) async => throw StateError('API is not configured');
}

/// FastAPI의 사용자 초기화 API를 호출한다.
class ApiUserRepository implements UserRepository {
  const ApiUserRepository(this.api);
  final ApiClient api;

  @override
  Future<void> completeOnboarding(String nickname) async {
    await api.post('/users/me/onboarding/complete', body: {'nickname': nickname});
  }

  @override
  Future<String> getNicknameSuggestion() async {
    final body = await api.get('/users/me/nickname-suggestion');
    final nickname = body['nickname'];
    if (nickname is! String || nickname.trim().isEmpty) throw const FormatException('Missing nickname');
    return nickname;
  }

  @override
  Future<UserBootstrapResult> bootstrap() async {
    final body = await api.post('/users/me/bootstrap');
    final userId = body['user_id'];
    if (userId is! String || userId.isEmpty) throw const FormatException('Missing user_id');
    final onboardingRequired = body['onboarding_required'];
    if (onboardingRequired is! bool) throw const FormatException('Missing onboarding_required');
    return UserBootstrapResult(userId: userId, onboardingRequired: onboardingRequired);
  }
}
