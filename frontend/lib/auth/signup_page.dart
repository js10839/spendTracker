import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/users/user_repository.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import 'auth_service.dart';

/// 인증된 회원의 표시 이름과 약관 동의를 받는다.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nickname = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _agreed = false;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  /// 서버에서 저장되지 않은 이름 후보를 가져온다.
  Future<void> _loadNickname() async {
    setState(() { _loading = true; _error = null; });
    try {
      final nickname = await UserRepository.instance.getNicknameSuggestion();
      if (mounted) setState(() => _nickname.text = nickname);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load a name. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 가입 정보를 저장한 후 카드 설정으로 이동한다.
  Future<void> _complete() async {
    setState(() { _saving = true; _error = null; });
    try {
      await UserRepository.instance.completeOnboarding(_nickname.text.trim());
      if (mounted) context.goNamed('onboarding-setup');
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save your information. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTokens.background,
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: IntrinsicHeight(
        child: Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBackButton(onPressed: () => context.goNamed('login-email')),
            const SizedBox(height: AppSpacing.twoXL),
            Text('Create account', style: AppTypography.caption.copyWith(color: AppTokens.textAccent)),
            const SizedBox(height: AppSpacing.sm),
            Text("Let's set you up", style: AppTypography.heading1),
            const SizedBox(height: AppSpacing.sm),
            Text('Just the basics — we never ask for card numbers.', style: AppTypography.bodyLarge.copyWith(color: AppTokens.textSecondary)),
            const SizedBox(height: AppSpacing.twoXL),
            Text('Display name', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textBody)),
            const SizedBox(height: AppSpacing.sm),
            if (_editing) AppInput(controller: _nickname, hintText: 'Display name', autofocus: true, onChanged: (_) => setState(() {})) else Container(
              height: 60, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(children: [
                Expanded(child: Text(_nickname.text, overflow: TextOverflow.ellipsis, style: AppTypography.bodyLarge)),
                if (!_loading && _nickname.text.isNotEmpty) InkWell(onTap: () => setState(() => _editing = true), child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppTokens.background, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [SvgPicture.asset('assets/onboarding/account_pencil.svg', width: 16, height: 16), const SizedBox(width: 6), Text('Edit', style: AppTypography.bodyMedium)]),
                )),
              ]),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('We picked a random name for you. Keep it, or change it anytime in Profile.', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            Text('Email', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textBody)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity, height: 60, alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text(AuthService.instance.currentEmail ?? '', style: AppTypography.bodyLarge, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: AppSpacing.twoXL),
            // TODO: 디자이너가 미선택 체크박스와 약관 링크를 확정하면 교체한다.
            Row(children: [Checkbox(value: _agreed, activeColor: AppTokens.brandLime, checkColor: AppTokens.textPrimary, onChanged: (value) => setState(() => _agreed = value ?? false)), Expanded(child: InkWell(onTap: () => setState(() => _agreed = !_agreed), child: Text('I agree to the Terms and Privacy Policy', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textBody))))]),
            if (_error != null) ...[const SizedBox(height: AppSpacing.sm), Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppTokens.statusDanger)), if (_nickname.text.isEmpty) TextButton(onPressed: _loadNickname, child: const Text('Try again'))],
            const Spacer(),
            const SizedBox(height: AppSpacing.twoXL),
            AppButton(label: 'Create account', labelStyle: AppButtonLabelStyle.regular, variant: !_agreed || _loading || _saving || _nickname.text.trim().isEmpty ? AppButtonVariant.disabled : AppButtonVariant.primary, onPressed: !_agreed || _loading || _saving || _nickname.text.trim().isEmpty ? null : _complete),
            const SizedBox(height: AppSpacing.twoXL),
            Center(child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text('Already have an account?', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary)),
              GestureDetector(onTap: () => context.goNamed('login-email'), child: Text('Log in', style: AppTypography.bodyMedium.copyWith(color: AppTokens.textPrimary))),
            ])),
          ],
        )),
      )),
    ))),
  );
}
