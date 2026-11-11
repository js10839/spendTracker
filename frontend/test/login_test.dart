import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/auth/login_code_page.dart';
import 'package:spending_tracker/auth/login_email_page.dart';
import 'package:spending_tracker/data/users/user_repository.dart';

class FakeUserRepository implements UserRepository {
  int calls = 0;
  bool shouldFail = false;
  @override
  Future<String> bootstrap() async {
    calls++;
    if (shouldFail) throw StateError('unavailable');
    return 'test-user';
  }
}

class FakeAuthService implements AuthService {
  final Object sessionIdentity = Object();
  @override
  Object get currentSessionIdentity => sessionIdentity;
  @override
  String? get currentUserId => 'test-user';
  @override
  bool get hasCurrentUsableSession => true;
  final sent = <String>[];
  final verified = <String>[];
  bool shouldFail = false;

  @override
  Future<bool> hasUsableSession() async => false;

  @override
  Future<bool> refreshUsableSession() async => false;

  @override
  Future<void> sendCode(String email) async {
    sent.add(email);
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    verified.add('$email:$code');
    if (shouldFail) throw const InvalidOtpException();
  }
}

void main() {
  testWidgets('기존 회원 이메일 발송, 코드 실패와 재전송 후 인증', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthService();
    final previous = AuthService.instance;
    final previousUsers = UserRepository.instance;
    final users = FakeUserRepository();
    UserRepository.instance = users;
    AuthService.instance = auth;
    addTearDown(() => AuthService.instance = previous);
    addTearDown(() => UserRepository.instance = previousUsers);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/login',
          name: 'login-email',
          builder: (_, _) => const LoginEmailPage(),
        ),
        GoRoute(
          path: '/login/code',
          name: 'login-code',
          builder: (_, state) => LoginCodePage(email: state.extra as String),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(auth.sent, isEmpty);
    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(auth.sent, ['test@example.com']);
    expect(find.text('Check your inbox'), findsOneWidget);
    auth.shouldFail = true;
    await tester.enterText(find.byKey(const Key('login-code')), '123456');
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Invalid or expired code. Please try again.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    await tester.ensureVisible(find.text('Resend code'));
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    expect(auth.sent, ['test@example.com', 'test@example.com']);
    auth.shouldFail = false;
    await tester.enterText(find.byKey(const Key('login-code')), '654321');
    await tester.pumpAndSettle();
    expect(auth.verified, [
      'test@example.com:123456',
      'test@example.com:654321',
    ]);
    expect(find.text('Home'), findsOneWidget);
    expect(users.calls, 1);
  });

  testWidgets('인증 후 초기화 실패 시 코드 검증 없이 재시도한다', (tester) async {
    final auth = FakeAuthService();
    final users = FakeUserRepository()..shouldFail = true;
    final oldAuth = AuthService.instance;
    final oldUsers = UserRepository.instance;
    AuthService.instance = auth;
    UserRepository.instance = users;
    addTearDown(() { AuthService.instance = oldAuth; UserRepository.instance = oldUsers; });
    final router = GoRouter(initialLocation: '/code', routes: [
      GoRoute(path: '/', name: 'home', builder: (_, _) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/code', builder: (_, _) => const LoginCodePage(email: 'test@example.com')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byKey(const Key('login-code')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Unable to set up your account. Please try again.'), findsOneWidget);
    users.shouldFail = false;
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(auth.verified.length, 1);
    expect(users.calls, 2);
  });
}
