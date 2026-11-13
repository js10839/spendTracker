import 'package:supabase_flutter/supabase_flutter.dart';

/// 인증번호가 유효하지 않거나 만료된 상태다.
class InvalidOtpException implements Exception {
  const InvalidOtpException();
}

/// 이메일 OTP 인증을 화면과 Supabase 사이에서 분리한다.
abstract class AuthService {
  static AuthService instance = const UnconfiguredAuthService();

  /// 현재 세션의 사용자와 만료 여부를 라우팅에 제공한다.
  String? get currentUserId;
  String? get currentEmail;
  bool get hasCurrentUsableSession;
  Object? get currentSessionIdentity;

  /// 이메일로 로그인 또는 가입 인증 코드를 발송한다.
  Future<void> sendCode(String email);

  /// 이메일과 인증 코드를 검증해 로그인한다.
  Future<void> verifyCode(String email, String code);

  /// 복원된 세션을 확인하고 만료된 경우 갱신한다.
  Future<bool> hasUsableSession();

  /// 서버가 토큰을 거부했을 때 세션을 다시 갱신한다.
  Future<bool> refreshUsableSession();
}

/// 공개 설정이 없는 실행 환경에서 인증 미설정을 알린다.
class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService();

  @override
  String? get currentUserId => null;
  @override
  String? get currentEmail => null;
  @override
  bool get hasCurrentUsableSession => false;
  @override
  Object? get currentSessionIdentity => null;

  @override
  Future<void> sendCode(String email) async =>
      throw StateError('Supabase is not configured');

  @override
  Future<void> verifyCode(String email, String code) async =>
      throw StateError('Supabase is not configured');

  @override
  Future<bool> hasUsableSession() async => throw StateError('Supabase is not configured');

  @override
  Future<bool> refreshUsableSession() async => throw StateError('Supabase is not configured');
}

/// 인증 요청과 세션 관리를 Supabase Auth에 위임한다.
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this.client);
  final SupabaseClient client;

  @override
  String? get currentUserId => client.auth.currentSession?.user.id;
  @override
  String? get currentEmail => client.auth.currentSession?.user.email;
  @override
  Object? get currentSessionIdentity => client.auth.currentSession;
  @override
  bool get hasCurrentUsableSession {
    final session = client.auth.currentSession;
    return session != null && !session.isExpired;
  }

  @override
  /// 네트워크 오류는 로그아웃으로 간주하지 않고 호출자에게 전달한다.
  Future<bool> hasUsableSession() async {
    final session = client.auth.currentSession;
    if (session == null) return false;
    if (!session.isExpired) return true;
    return refreshUsableSession();
  }

  @override
  /// 인증 서버가 세션 무효를 확인한 경우에만 로그인 상태를 종료한다.
  Future<bool> refreshUsableSession() async {
    if (client.auth.currentSession == null) return false;
    try {
      await client.auth.refreshSession();
      final current = client.auth.currentSession;
      return current != null && !current.isExpired;
    } on AuthSessionMissingException {
      return false;
    } on AuthApiException catch (error) {
      const invalidSessionCodes = {'refresh_token_not_found', 'refresh_token_already_used', 'session_not_found', 'session_expired'};
      if (invalidSessionCodes.contains(error.code) && client.auth.currentSession == null) return false;
      rethrow;
    }
  }

  @override
  // 신규 가입과 기존 로그인 템플릿 모두 OTP 표시를 위해 {{ .Token }} 설정이 필요하다.
  Future<void> sendCode(String email) =>
      client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<void> verifyCode(String email, String code) async {
    try {
      final response = await client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (response.session == null) {
        throw StateError('Authentication did not return a session');
      }
    } on AuthApiException catch (error) {
      if (error.code == 'otp_expired') throw const InvalidOtpException();
      rethrow;
    }
  }
}
