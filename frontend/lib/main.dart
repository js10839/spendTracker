import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'auth/auth_service.dart';

// Flutter 앱의 진입점이다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: key);
    AuthService.instance = SupabaseAuthService(Supabase.instance.client);
  }
  runApp(const SpendingTrackerApp());
}

class SpendingTrackerApp extends StatelessWidget {
  const SpendingTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제 페이지가 정해지기 전까지 기존 첫 화면을 라우터의 홈으로 사용한다.
    return MaterialApp.router(
      title: 'Spending Tracker',
      routerConfig: appRouter,
    );
  }
}
