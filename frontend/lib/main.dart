import 'package:flutter/material.dart';

import 'app_router.dart';

// Flutter 앱의 진입점이다.
void main() {
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
