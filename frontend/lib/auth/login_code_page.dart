import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../data/users/user_repository.dart';
import 'auth_service.dart';
import 'member_bootstrap.dart';

/// 기존 회원의 이메일 OTP를 확인한다.
class LoginCodePage extends StatefulWidget {
  const LoginCodePage({super.key, required this.email});
  final String email;

  @override
  State<LoginCodePage> createState() => _LoginCodePageState();
}

class _LoginCodePageState extends State<LoginCodePage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _remaining = 60;
  bool _loading = false;
  String? _message;
  bool _error = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    _startCooldown();
  }

  /// 포커스에 맞춰 현재 인증번호 칸을 갱신한다.
  void _focusChanged() => setState(() {});

  /// 서버의 기본 발송 간격 동안 재요청을 막는다.
  void _startCooldown() {
    _timer?.cancel();
    _remaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  /// 여섯 자리가 입력되면 Supabase에 코드를 검증한다.
  Future<void> _verify(String code) async {
    if (code.length != 6 || _loading) return;
    setState(() {
      _loading = true;
      _message = null;
      _error = false;
    });
    try {
      await AuthService.instance.verifyCode(widget.email, code);
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is InvalidOtpException
              ? 'Invalid or expired code. Please try again.'
              : 'Unable to verify the code. Please try again.';
          _error = true;
        });
      }
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    setState(() => _verified = true);
    await _bootstrap();
  }

  /// 인증이 완료된 세션으로 앱 데이터를 초기화하고 실패 시 재시도한다.
  Future<void> _bootstrap() async {
    setState(() { _loading = true; _message = null; _error = false; });
    try {
      final access = await MemberBootstrap(AuthService.instance, UserRepository.instance).run();
      if (mounted) context.goNamed(access != null ? 'home' : 'login-email', extra: access);
    } catch (_) {
      if (mounted) setState(() { _message = 'Unable to set up your account. Please try again.'; _error = true; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 같은 이메일로 기존 회원 인증 코드를 다시 요청한다.
  Future<void> _resend() async {
    if (_loading || _remaining > 0) return;
    setState(() {
      _loading = true;
      _message = null;
      _error = false;
    });
    try {
      await AuthService.instance.sendCode(widget.email);
      if (!mounted) return;
      setState(() {
        _startCooldown();
        _message = 'A new code has been sent.';
        _code.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to send a code. Please try again.';
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 기기에 설치된 이메일 앱을 열거나 사용할 수 없음을 알린다.
  Future<void> _openEmail() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        final opened =
            await const MethodChannel('dadali/email_app')
                .invokeMethod<bool>('open') ??
            false;
        if (opened || !mounted) return;
      } catch (_) {
        if (!mounted) return;
      }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final apps = <({String label, Uri uri})>[
        (label: 'Mail', uri: Uri.parse('message://')),
        (label: 'Gmail', uri: Uri.parse('googlegmail://')),
        (label: 'Outlook', uri: Uri.parse('ms-outlook://')),
      ];
      final available = <({String label, Uri uri})>[];
      for (final app in apps) {
        try {
          if (await canLaunchUrl(app.uri)) available.add(app);
        } catch (_) {
          // 확인할 수 없는 앱은 선택 목록에서 제외한다.
        }
      }
      if (!mounted) return;
      if (available.isNotEmpty) {
        final chosen = await showModalBottomSheet<Uri>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final app in available)
                  ListTile(
                    title: Text(app.label),
                    onTap: () => Navigator.pop(context, app.uri),
                  ),
              ],
            ),
          ),
        );
        if (chosen == null || !mounted) return;
        try {
          if (await launchUrl(chosen, mode: LaunchMode.externalApplication) ||
              !mounted) {
            return;
          }
        } catch (_) {
          if (!mounted) return;
        }
      }
    }
    if (mounted) {
      setState(() {
        _message = 'Unable to open an email app on this device.';
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTokens.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                4,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppBackButton(onPressed: () => context.pop()),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'dadali',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppTokens.textAccent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Check your inbox',
                    textAlign: TextAlign.center,
                    style: AppTypography.heading1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We sent a 6-digit code to ${widget.email}.\nEnter it below.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 6; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AppCodeDigit(
                                  state: i < _code.text.length
                                      ? AppCodeDigitState.filled
                                      : i == _code.text.length &&
                                            _focus.hasFocus
                                      ? AppCodeDigitState.active
                                      : AppCodeDigitState.empty,
                                  digit: i < _code.text.length
                                      ? _code.text[i]
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.01,
                          child: TextField(
                            key: const Key('login-code'),
                            controller: _code,
                            focusNode: _focus,
                            autofocus: true,
                            readOnly: _loading || _verified,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _message = null;
                                _error = false;
                              });
                              if (value.length == 6) _verify(value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_message != null) ...[
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: _error
                            ? AppTokens.statusDanger
                            : AppTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_verified && _error) ...[
                    AppButton(label: 'Try again', onPressed: _loading ? null : _bootstrap),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'Use another email',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTokens.brandPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(label: 'Open email app', onPressed: _openEmail),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _remaining > 0
                        ? 'Resend code ($_remaining s)'
                        : 'Resend code',
                    onPressed: !_verified && !_loading && _remaining == 0 ? _resend : null,
                    variant: !_verified && !_loading && _remaining == 0
                        ? AppButtonVariant.outline
                        : AppButtonVariant.disabled,
                    disabledBackgroundColor: AppTokens.surface,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
