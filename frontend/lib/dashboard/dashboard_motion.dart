import 'package:flutter/material.dart';

import '../design_system/tokens.dart';

const dashboardEaseInOut = Cubic(.42, 0, .58, 1);
const dashboardEaseOut = Cubic(0, 0, .58, 1);
const dashboardPeriodDuration = Duration(milliseconds: 350);
const dashboardCashFlowDuration = Duration(milliseconds: 250);
const dashboardSpendingDuration = Duration(milliseconds: 300);
const dashboardHomeDuration = Duration(milliseconds: 400);
const dashboardFadeDuration = Duration(milliseconds: 250);

const dashboardHeaderHero = 'dashboard-home-header';
const dashboardCardHero = 'dashboard-home-card';
const dashboardDetailOrigin = 'dashboard-detail';

Duration dashboardDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

Widget dashboardFade(
  Animation<double> animation,
  Widget child, {
  Curve curve = dashboardEaseOut,
}) => FadeTransition(
  opacity: animation.drive(CurveTween(curve: curve)),
  child: child,
);

Future<T?> pushDashboardDetail<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final duration = dashboardDuration(context, dashboardFadeDuration);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (_, animation, _, child) =>
          dashboardFade(animation, child),
      pageBuilder: (context, _, _) => Scaffold(
        backgroundColor: AppTokens.background,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppTokens.background,
        ),
        body: SafeArea(top: false, child: Builder(builder: builder)),
      ),
    ),
  );
}

Widget dashboardSurfaceFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final from = fromContext.widget as Hero;
  final to = toContext.widget as Hero;
  final isHeader = from.tag == dashboardHeaderHero;
  final fromColor = isHeader
      ? (from.child as Material).color!
      : AppTokens.background;
  final toColor = isHeader
      ? (to.child as Material).color!
      : AppTokens.background;
  final progress = direction == HeroFlightDirection.push
      ? animation
      : ReverseAnimation(animation);
  return AnimatedBuilder(
    animation: progress,
    builder: (_, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(fromColor, toColor, progress.value),
        borderRadius: BorderRadius.circular(isHeader ? 0 : AppSpacing.twoXL),
        border: isHeader ? null : Border.all(color: AppTokens.borderSubtle),
      ),
    ),
  );
}
