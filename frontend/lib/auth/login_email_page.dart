import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'auth_service.dart';

/// 기존 회원의 이메일을 입력받아 인증 코드를 요청한다.
class LoginEmailPage extends StatefulWidget {
  const LoginEmailPage({super.key});

  @override
  State<LoginEmailPage> createState() => _LoginEmailPageState();
}

class _LoginEmailPageState extends State<LoginEmailPage> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  /// 이메일 형식을 확인하고 기존 회원에게 인증 코드를 전송한다.
  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendCode(email);
      if (mounted) context.pushNamed('login-code', extra: email);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to send a code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
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
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  72,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'dadali',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppTokens.textAccent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'What’s your email',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Track every card by its statement cycle.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 9),
                    AppInput(
                      key: const Key('login-email'),
                      controller: _email,
                      hintText: 'Your email',
                      keyboardType: TextInputType.emailAddress,
                      inputStyle: AppInputStyle.onboardingEmail,
                      hasError: _error != null,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        _error ?? 'We’ll send you a confirmation email.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: _error == null
                              ? AppTokens.textSecondary
                              : AppTokens.statusDanger,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.twoXL),
                    AppButton(
                      label: 'Continue',
                      onPressed: !_loading && _email.text.trim().isNotEmpty
                          ? _send
                          : null,
                      variant: _loading || _email.text.trim().isEmpty
                          ? AppButtonVariant.disabled
                          : AppButtonVariant.primary,
                      disabledBackgroundColor: AppTokens.surface,
                      labelStyle: AppButtonLabelStyle.regular,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
