import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spending_tracker/auth/auth_service.dart';
import 'package:spending_tracker/auth/signup_page.dart';
import 'package:spending_tracker/data/users/user_repository.dart';

class SignupAuth implements AuthService {
  @override
  String? get currentEmail => 'user@example.com';
  @override
  String? get currentUserId => 'user';
  @override
  Object? get currentSessionIdentity => null;
  @override
  bool get hasCurrentUsableSession => true;
  @override
  Future<bool> hasUsableSession() async => true;
  @override
  Future<bool> refreshUsableSession() async => true;
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
}

class SignupUsers implements UserRepository {
  String? saved;
  @override
  Future<UserBootstrapResult> bootstrap() async => const UserBootstrapResult(userId: 'user', onboardingRequired: true);
  @override
  Future<String> getNicknameSuggestion() async => 'Calm Otter';
  @override
  Future<void> completeOnboarding(String nickname) async => saved = nickname;
}

void main() {
  testWidgets('동의 후 추천된 이름을 저장하고 설정으로 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final oldAuth = AuthService.instance;
    final oldUsers = UserRepository.instance;
    final users = SignupUsers();
    AuthService.instance = SignupAuth();
    UserRepository.instance = users;
    addTearDown(() { AuthService.instance = oldAuth; UserRepository.instance = oldUsers; });
    final router = GoRouter(initialLocation: '/signup', routes: [
      GoRoute(path: '/signup', builder: (_, _) => const SignupPage()),
      GoRoute(path: '/setup', name: 'onboarding-setup', builder: (_, _) => const Scaffold(body: Text('Setup'))),
      GoRoute(path: '/login', name: 'login-email', builder: (_, _) => const Scaffold()),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Calm Otter'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus ?? Focus.of(tester.element(find.byType(TextField))).hasFocus, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.ensureVisible(find.text('I agree to the Terms and Privacy Policy'));
    await tester.tap(find.text('I agree to the Terms and Privacy Policy'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.text('I agree to the Terms and Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();
    expect(users.saved, 'Calm Otter');
    expect(find.text('Setup'), findsOneWidget);
  });
}
