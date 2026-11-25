import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/profile/profile_page.dart';

/// 실제 인증 서버 없이 로그아웃의 성공과 실패를 제어한다.
class _Auth implements AuthService, SignOutService {
  bool fail = false;
  int calls = 0;
  @override
  String? get currentEmail => 'test@example.com';
  @override
  String? get currentUserId => 'user';
  @override
  bool get hasCurrentUsableSession => true;
  @override
  Object? get currentSessionIdentity => null;
  @override
  Future<void> signOut() async { calls++; if (fail) throw Exception('offline'); }
  @override
  Future<bool> hasUsableSession() async => true;
  @override
  Future<bool> refreshUsableSession() async => true;
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
}

void main() {
  testWidgets('로그아웃은 확인 후 세션 종료에 성공했을 때만 이동한다', (tester) async {
    final old = AuthService.instance;
    final auth = _Auth();
    AuthService.instance = auth;
    final router = GoRouter(initialLocation: '/', routes: [GoRoute(path: '/', builder: (_, _) => const ProfilePage(isMember: true)), GoRoute(path: '/onboarding', builder: (_, _) => const Scaffold(body: Text('Onboarding')))]);
    addTearDown(() { AuthService.instance = old; router.dispose(); });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    auth.fail = true;
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.text('Unable to log out. Please try again.'), findsOneWidget);
    expect(find.text('Onboarding'), findsNothing);
    auth.fail = false;
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.text('Onboarding'), findsOneWidget);
  });
}
