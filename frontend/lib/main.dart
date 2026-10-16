import 'package:flutter/material.dart';

// Flutter 앱의 진입점이다.
void main() {
  runApp(const SpendingTrackerApp());
}

class SpendingTrackerApp extends StatelessWidget {
  const SpendingTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 기능 화면이 정해지기 전에는 실행 확인을 위한 최소 홈 화면만 제공한다.
    return const MaterialApp(
      title: 'Spending Tracker',
      home: Scaffold(body: Center(child: Text('Spending Tracker'))),
    );
  }
}
