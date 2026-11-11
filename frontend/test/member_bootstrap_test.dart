import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/auth/member_bootstrap.dart';
import 'package:spending_tracker/core/api_client.dart';
import 'package:spending_tracker/data/users/user_repository.dart';

class BootstrapAuth implements AuthService {
  String userId = 'user';
  Object sessionIdentity = Object();
  @override
  Object get currentSessionIdentity => sessionIdentity;
  @override
  String? get currentUserId => userId;
  @override
  bool get hasCurrentUsableSession => true;
  bool refreshed = true;
  int calls = 0;
  @override
  Future<bool> refreshUsableSession() async { calls++; return refreshed; }
  @override
  Future<bool> hasUsableSession() async => true;
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
}

class BootstrapUsers implements UserRepository {
  int calls = 0;
  int status = 401;
  @override
  Future<String> bootstrap() async {
    calls++;
    if (calls == 1) throw ApiException(status);
    return 'user';
  }
}

class PendingUsers implements UserRepository {
  final result = Completer<String>();
  @override
  Future<String> bootstrap() => result.future;
}

void main() {
  test('401일 때 토큰 갱신 후 초기화 요청을 한 번 다시 시도한다', () async {
    final auth = BootstrapAuth();
    final users = BootstrapUsers();
    expect((await MemberBootstrap(auth, users).run())?.userId, 'user');
    expect(auth.calls, 1);
    expect(users.calls, 2);
  });

  test('갱신할 세션이 없으면 초기화를 다시 시도하지 않는다', () async {
    final auth = BootstrapAuth()..refreshed = false;
    final users = BootstrapUsers();
    expect(await MemberBootstrap(auth, users).run(), isNull);
    expect(users.calls, 1);
  });

  test('서버 오류는 세션을 갱신하거나 로그아웃하지 않는다', () async {
    final auth = BootstrapAuth();
    final users = BootstrapUsers()..status = 503;
    await expectLater(MemberBootstrap(auth, users).run(), throwsA(isA<ApiException>()));
    expect(auth.calls, 0);
    expect(users.calls, 1);
  });

  test('초기화 중 계정이 바뀌면 이전 계정의 결과를 사용하지 않는다', () async {
    final auth = BootstrapAuth();
    final users = PendingUsers();
    final result = MemberBootstrap(auth, users).run();
    auth.userId = 'another-user';
    users.result.complete('user');
    await expectLater(result, throwsStateError);
  });

  test('로그아웃 후 같은 계정의 새 세션에서는 이전 결과를 재사용하지 않는다', () async {
    final auth = BootstrapAuth();
    final users = PendingUsers();
    final future = MemberBootstrap(auth, users).run();
    users.result.complete('user');
    final access = (await future)!;
    expect(access.matches(auth), isTrue);
    auth.sessionIdentity = Object();
    expect(access.matches(auth), isFalse);
  });
}
