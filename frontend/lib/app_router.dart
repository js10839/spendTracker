import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 앱의 화면 경로를 한곳에서 관리한다.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Spending Tracker'))),
    ),
  ],
);
