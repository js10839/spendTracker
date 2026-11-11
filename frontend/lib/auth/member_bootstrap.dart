import '../core/api_client.dart';
import '../data/users/user_repository.dart';
import 'auth_service.dart';

/// 현재 이동에서만 사용하는 서버 초기화 성공 결과다.
class MemberHomeAccess {
  const MemberHomeAccess._(this.userId, this.onboardingRequired, this._sessionIdentity);
  final String userId;
  final bool onboardingRequired;
  final Object _sessionIdentity;

  /// 인증 완료 당시의 세션에만 홈 진입 결과를 적용한다.
  bool matches(AuthService auth) => !onboardingRequired && matchesSession(auth);

  /// 초기화 결과가 현재 회원 세션에서 생성됐는지 확인한다.
  bool matchesSession(AuthService auth) => auth.hasCurrentUsableSession && auth.currentUserId == userId && identical(auth.currentSessionIdentity, _sessionIdentity);
}

/// 사용자가 온보딩에서 비로그인 사용을 명시적으로 선택한 이동이다.
class GuestHomeAccess {
  const GuestHomeAccess();
}

/// 인증된 회원의 초기화와 만료 토큰 재시도를 담당한다.
class MemberBootstrap {
  const MemberBootstrap(this.auth, this.users);
  final AuthService auth;
  final UserRepository users;

  /// 401에서는 세션을 한 번 갱신한 뒤 같은 초기화를 재시도한다.
  Future<MemberHomeAccess?> run() async {
    UserBootstrapResult result;
    try {
      result = await users.bootstrap();
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      if (!await auth.refreshUsableSession()) return null;
      result = await users.bootstrap();
    }
    // 요청 중 계정이 바뀌면 이전 계정의 결과로 홈에 진입하지 않는다.
    final sessionIdentity = auth.currentSessionIdentity;
    if (auth.currentUserId != result.userId || !auth.hasCurrentUsableSession || sessionIdentity == null) throw StateError('Session changed during bootstrap');
    return MemberHomeAccess._(result.userId, result.onboardingRequired, sessionIdentity);
  }
}
