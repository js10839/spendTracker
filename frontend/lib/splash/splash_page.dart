import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../auth/member_bootstrap.dart';
import '../data/users/user_repository.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';

/// 스플래시에서 다음 화면으로 전환할 때만 페이드를 적용한다.
const splashExitTransition = 'splash-fade';

const splashFadeDuration = Duration(milliseconds: 250);

/// 스플래시 재생과 인증·초기화 확인이 끝나면 다음 화면으로 이동한다.
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
  bool _animationFinished = false;
  bool _loading = true;
  bool _failed = false;
  String? _destination;
  MemberHomeAccess? _memberAccess;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  /// 회원 세션이 있을 때만 백엔드 초기화 성공을 기다린다.
  Future<void> _prepare() async {
    setState(() { _loading = true; _failed = false; _destination = null; _memberAccess = null; });
    try {
      final signedIn = await AuthService.instance.hasUsableSession();
      final access = signedIn ? await MemberBootstrap(AuthService.instance, UserRepository.instance).run() : null;
      if (!mounted) return;
      setState(() { _loading = false; _memberAccess = access; _destination = access == null ? 'onboarding' : access.onboardingRequired ? 'signup' : 'home'; });
      _navigateWhenReady();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  /// 애니메이션과 초기화가 모두 끝났을 때만 화면을 이동한다.
  void _navigateWhenReady() {
    if (!_animationFinished || _loading || _destination == null || !mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final destination = _destination!;
    _destination = null;
    context.goNamed(destination, extra: destination == 'onboarding' ? splashExitTransition : _memberAccess);
  }

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
        setState(() => _animationFinished = true);
        _navigateWhenReady();
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
      body: Stack(children: [
        Positioned.fill(child: LayoutBuilder(
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
        )),
        if (_animationFinished && (_loading || _failed))
          Positioned(left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.fiveXL, child: _startupStatus()),
      ]),
    ),
  );

  /// 최종 디자인이 나오기 전까지 표시하는 임시 로딩·재시도 UI다.
  Widget _startupStatus() {
    // TODO: 디자이너가 정한 초기화 오류 및 재시도 화면으로 교체한다.
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTokens.textPrimary));
    return Material(
      color: AppTokens.background,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Unable to start. Please check your connection and try again.', textAlign: TextAlign.center, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Try again', onPressed: _prepare),
        ]),
      ),
    );
  }
}
