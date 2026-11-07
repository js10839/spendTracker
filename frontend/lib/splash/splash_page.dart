import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design_system/tokens.dart';

/// 스플래시에서 다음 화면으로 전환할 때만 페이드를 적용한다.
const splashExitTransition = 'splash-fade';

const splashFadeDuration = Duration(milliseconds: 250);

/// GIF를 끝까지 재생하고 마지막 화면을 보여준 뒤 온보딩으로 이동한다.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  // TODO: 실제 기기에서 확인한 뒤 GIF 재생 시간을 더 줄일지 검토한다.
  // 원본 GIF는 150프레임이므로 마지막 프레임 인덱스는 149다.
  static const _lastFrameIndex = 149;
  static const _finalFrameDuration = Duration(milliseconds: 20);
  Timer? _timer;
  bool _finishScheduled = false;
  bool _showFinalFrame = false;
  bool _holdStarted = false;

  /// GIF의 마지막 프레임이 그려진 뒤 같은 정지 이미지로 전환한다.
  void _showLastFrame() {
    if (_finishScheduled) return;
    _finishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showFinalFrame = true);
    });
  }

  /// 마지막 이미지를 원본 GIF의 마지막 프레임 길이만큼 표시한다.
  void _startFinalFrameTimer() {
    if (_holdStarted) return;
    _holdStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(_finalFrameDuration, () {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        // TODO: 인증 세션 확인이 준비되면 홈 또는 온보딩으로 분기한다.
        context.goNamed('onboarding', extra: splashExitTransition);
      });
    });
  }

  @override
  /// 화면이 닫히면 예약된 이동을 취소한다.
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  /// 네이티브 시작 화면과 같은 배경 위에 원본 GIF를 표시한다.
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: AppTokens.splashBackground,
      systemNavigationBarColor: AppTokens.splashBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: AppTokens.splashBackground,
      body: LayoutBuilder(
        builder: (context, constraints) => ClipRect(
          child: Transform.translate(
            // 원본 로고가 중앙보다 20px 위에 있어 GIF와 마지막 프레임을 함께 보정한다.
            offset: Offset(0, constraints.maxHeight * 20 / 1688),
            child: Transform.scale(
              // 이동한 뒤에도 원본 배경이 화면 가장자리를 채우도록 한다.
              scale: 1.025,
              child: SizedBox.expand(child: Image.asset(
          _showFinalFrame
              ? 'assets/branding/splash_final.png'
              : 'assets/branding/splash.gif',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              if (_showFinalFrame) {
                _startFinalFrameTimer();
              } else if (frame >= _lastFrameIndex) {
                _showLastFrame();
              }
            }
            return child;
          },
              )),
            ),
          ),
        ),
      ),
    ),
  );
}
