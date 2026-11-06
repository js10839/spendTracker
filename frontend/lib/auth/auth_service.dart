import 'package:supabase_flutter/supabase_flutter.dart';

/// 이메일 OTP 인증을 화면과 Supabase 사이에서 분리한다.
abstract class AuthService {
  static AuthService instance = const UnconfiguredAuthService();

  /// 기존 회원에게만 인증 코드를 발송한다.
  Future<void> sendCode(String email);

  /// 이메일과 인증 코드를 검증해 로그인한다.
  Future<void> verifyCode(String email, String code);
}

/// 공개 설정이 없는 실행 환경에서 인증 미설정을 알린다.
class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService();

  @override
  Future<void> sendCode(String email) async =>
      throw StateError('Supabase is not configured');

  @override
  Future<void> verifyCode(String email, String code) async =>
      throw StateError('Supabase is not configured');
}

/// 인증 요청과 세션 관리를 Supabase Auth에 위임한다.
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this.client);
  final SupabaseClient client;

  @override
  Future<void> sendCode(String email) =>
      client.auth.signInWithOtp(email: email, shouldCreateUser: false);

  @override
  Future<void> verifyCode(String email, String code) async {
    final response = await client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.email,
    );
    if (response.session == null) {
      throw StateError('Authentication did not return a session');
    }
  }
}
