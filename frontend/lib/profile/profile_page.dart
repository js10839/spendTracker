import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';

/// 회원과 게스트의 프로필 및 설정 진입점을 표시한다.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.isMember, this.onDashboard});
  final bool isMember;
  final VoidCallback? onDashboard;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _signingOut = false;

  /// 세션 종료에 성공한 경우에만 온보딩으로 이동한다.
  Future<void> _signOut() async {
    final confirmed = await _confirm('Log out?', 'Are you sure you want to log out?', 'Log out');
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      final auth = AuthService.instance;
      if (auth is! SignOutService) throw StateError('Sign out is unavailable');
      await (auth as SignOutService).signOut();
      if (mounted) context.go('/onboarding');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to log out. Please try again.')));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  /// 공통 버튼을 사용해 임시 확인 대화상자를 표시한다.
  Future<bool?> _confirm(String title, String description, String action, {bool danger = false}) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTokens.background,
      title: Text(title, style: AppTypography.heading2),
      content: Text(description, style: AppTypography.bodyMedium),
      actions: [
        AppButton(label: action, variant: danger ? AppButtonVariant.danger : AppButtonVariant.primary, onPressed: () => Navigator.pop(context, true)),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: 'Cancel', variant: AppButtonVariant.surface, onPressed: () => Navigator.pop(context, false)),
      ],
    ),
  );

  /// API 연결 전에는 안내만 보여주고 실제 변경은 수행하지 않는다.
  void _unavailable() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));

  /// 관련 페이지를 현재 프로필 위에 연다.
  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        _header(),
        const SizedBox(height: 14),
        if (widget.isMember) _scans() else _guestCard(),
        const SizedBox(height: 14),
        if (!widget.isMember) ...[
          // TODO: 게스트 SQLite 보관이 완성되면 실제 저장 안내를 연결한다.
          const _ProfileNotice(icon: Icons.phone_android, title: 'Saved on this phone only', subtitle: 'Sign in to keep your data if you switch or lose your phone.'),
          const SizedBox(height: 14),
        ],
        Row(children: [
          if (widget.isMember) ...[Expanded(child: _ProfileTile(icon: Icons.auto_awesome_outlined, title: 'Go Pro', onTap: () => _open(const _ProPage()))), const SizedBox(width: 10)],
          Expanded(child: _ProfileTile(icon: Icons.lock_outline, title: 'Privacy', onTap: _unavailable)),
          const SizedBox(width: 10),
          Expanded(child: _ProfileTile(icon: Icons.description_outlined, title: 'Terms', onTap: _unavailable)),
        ]),
        const SizedBox(height: 14),
        _ProfileNotice(icon: Icons.shield_outlined, title: widget.isMember ? 'AI receipt notice' : 'AI Receipt Processing', subtitle: widget.isMember ? 'What we send to AI' : 'See what data we share with AI', onTap: _unavailable),
        if (widget.isMember) ...[const SizedBox(height: 14), _account()],
      ])),
      bottomNavigationBar: SafeArea(top: false, child: AppBottomNavigation(selectedIndex: 4, onSelected: (index) { if (index == 0) context.pop(); if (index == 1) widget.onDashboard?.call(); })),
    ),
  );

  /// 인증 여부에 따른 상단 프로필 정보를 표시한다.
  Widget _header() => Row(children: [
    CircleAvatar(radius: 26, backgroundColor: AppTokens.brandPurple, child: Text(widget.isMember ? 'M' : 'G', style: AppTypography.heading3.copyWith(color: AppTokens.textInverse))),
    const SizedBox(width: AppSpacing.md),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(widget.isMember ? 'Mellow Otter' : 'Guest', style: AppTypography.heading3), if (widget.isMember) IconButton(onPressed: _unavailable, icon: const Icon(Icons.edit_outlined, size: 16))]),
      Text(widget.isMember ? 'Free plan · USD' : 'Not signed in', style: AppTypography.caption.copyWith(color: AppTokens.textSecondary)),
    ])),
    IconButton(onPressed: _unavailable, icon: const Icon(Icons.notifications_none)),
    IconButton(onPressed: _unavailable, icon: const Icon(Icons.more_horiz)),
  ]);

  /// 영수증 잔여량 API 연결 전의 예시 데이터를 표시한다.
  Widget _scans() => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Receipt scans left', style: AppTypography.bodyMedium), Flexible(child: Text('Resets Sep 1 · no rollover', textAlign: TextAlign.end, style: AppTypography.caption.copyWith(color: AppTokens.textSecondary)))]),
    const SizedBox(height: 10),
    RichText(text: TextSpan(style: AppTypography.displayLarge, children: [const TextSpan(text: '7'), TextSpan(text: ' / 10', style: AppTypography.heading2.copyWith(color: AppTokens.textSecondary))])),
    const SizedBox(height: 10),
    ClipRRect(borderRadius: BorderRadius.circular(AppRadius.full), child: const LinearProgressIndicator(value: .7, minHeight: 8, backgroundColor: AppTokens.borderSubtle, color: AppTokens.brandPurple)),
  ]));

  /// 게스트의 임시 가입 안내를 표시한다.
  Widget _guestCard() => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('FREE TO JOIN', style: AppTypography.captionEyebrow.copyWith(color: AppTokens.textAccent)),
    const SizedBox(height: 14), Text('Create your account', style: AppTypography.heading1),
    const SizedBox(height: 14),
    for (final label in ['Back up your cards, calendar & receipts', 'Pick up where you left off on any device', '10 free AI receipt scans every month']) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [const Icon(Icons.check_circle_outline, size: 20, color: AppTokens.brandPurple), const SizedBox(width: 10), Expanded(child: Text(label, style: AppTypography.bodyMedium))])),
    AppButton(label: 'Create account', onPressed: () => context.push('/login')),
    Center(child: TextButton(onPressed: () => context.push('/login'), child: const Text('Already have an account? Log in'))),
  ]));

  /// 계정 작업을 목록으로 표시한다.
  Widget _account() => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('ACCOUNT', style: AppTypography.captionEyebrow.copyWith(color: AppTokens.textSecondary)),
    _ProfileRow(title: 'Email', trailing: AuthService.instance.currentEmail ?? '', onTap: null),
    _ProfileRow(title: 'Recover deleted data', onTap: () => _open(_RecoveryPage(email: AuthService.instance.currentEmail))),
    _ProfileRow(title: 'Log out', onTap: _signingOut ? null : _signOut),
    _ProfileRow(title: 'Delete account', onTap: () async { await _confirm('Delete your account?', "This permanently deletes all your expenses, cards, categories and receipt images. This can't be undone.", 'Yes, delete everything', danger: true); }),
  ]));
}

/// 프로필에서 반복되는 표면과 여백이다.
class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppRadius.lg)), child: child);
}

/// 프로필 설정 목록의 한 행이다.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.title, this.trailing, this.onTap});
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Expanded(child: Text(title, style: AppTypography.bodyLarge)), if (trailing != null) Flexible(child: Text(trailing!, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary))) else const Icon(Icons.chevron_right, size: 16, color: AppTokens.textSecondary)])));
}

/// 프로필의 바로가기 타일이다.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppRadius.lg), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.lg), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 20, backgroundColor: AppTokens.background, child: Icon(icon, color: AppTokens.textPrimary, size: 22)), const SizedBox(height: 12), Text(title, style: AppTypography.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis)]))));
}

/// 아이콘과 두 줄 설명이 있는 프로필 안내 행이다.
class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _Surface(child: InkWell(onTap: onTap, child: Row(children: [Icon(icon, color: AppTokens.textPrimary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.bodyLargeStrong), Text(subtitle, style: AppTypography.bodyMedium.copyWith(color: AppTokens.textSecondary))])), if (onTap != null) const Icon(Icons.chevron_right, size: 16)])));
}

/// Pro 기능 비교를 임시 데이터로 표시한다.
class _ProPage extends StatelessWidget {
  const _ProPage();
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTokens.background, appBar: AppBar(backgroundColor: AppTokens.background), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [Text('PRO', style: AppTypography.captionEyebrow.copyWith(color: AppTokens.textAccent)), const SizedBox(height: 12), Text('dadali Pro', style: AppTypography.heading1), const SizedBox(height: 12), Text('Unlock more cards and scans to track every billing cycle.', style: AppTypography.bodyLarge), const SizedBox(height: 20), _Surface(child: Column(children: [const _ComparisonRow('','Free','Pro'), const _ComparisonRow('Cards','2','Unlimited'), const _ComparisonRow('Receipt scans','10 / mo','50 / mo'), const _ComparisonRow('Scan past receipts','—','✓'), const _ComparisonRow('Calendar feed','—','✓'), const _ComparisonRow('Custom AI icons','—','✓')])), const SizedBox(height: 20), Text('\$—.99 / month · Price TBD', style: AppTypography.heading3), const SizedBox(height: 12), AppButton(label: 'Start Pro', onPressed: null), const SizedBox(height: 8), Text('Cancel anytime · Secure checkout on the web', style: AppTypography.caption.copyWith(color: AppTokens.textSecondary))])));
}

/// Pro 비교표의 세 열을 정렬한다.
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow(this.label, this.free, this.pro);
  final String label, free, pro;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Row(children: [Expanded(flex: 2, child: Text(label, style: AppTypography.bodyLarge)), Expanded(child: Text(free, textAlign: TextAlign.center, style: AppTypography.bodyMedium)), Expanded(child: Text(pro, textAlign: TextAlign.center, style: AppTypography.bodyMediumStrong))]));
}

/// 서버 연결 전 복구 요청 입력 상태만 유지한다.
class _RecoveryPage extends StatefulWidget {
  const _RecoveryPage({this.email});
  final String? email;
  @override
  State<_RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<_RecoveryPage> {
  final Set<String> selected = {};
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppTokens.background, appBar: AppBar(backgroundColor: AppTokens.background, title: const Text('Recover deleted data')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [Text('Deleted something by mistake?', style: AppTypography.heading1), const SizedBox(height: 12), Text("Tell us what's missing and we'll try to bring it back.", style: AppTypography.bodyLarge), const SizedBox(height: 24), Text('What do you need back?', style: AppTypography.bodyLargeStrong), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [for (final label in ['Expenses', 'Items', 'Cards', 'Receipt images']) FilterChip(label: Text(label), selected: selected.contains(label), onSelected: (value) => setState(() { if (value) { selected.add(label); } else { selected.remove(label); } }))]), const SizedBox(height: 8), Text('Pick all that apply.', style: AppTypography.bodyMedium), const SizedBox(height: 24), Text('About when was it deleted?', style: AppTypography.bodyLargeStrong), const SizedBox(height: 12), TextField(decoration: const InputDecoration(hintText: 'Oct 24, 2026')), const SizedBox(height: 8), Text('A rough date is fine.', style: AppTypography.bodyMedium), const SizedBox(height: 24), Text('Anything else that helps?', style: AppTypography.bodyLargeStrong), const SizedBox(height: 12), const TextField(maxLines: 3, decoration: InputDecoration(hintText: 'e.g. Costco receipt from Oct 20, about \$86')), const SizedBox(height: 8), Text('Store, amount or card name.', style: AppTypography.bodyMedium), const SizedBox(height: 24), const AppButton(label: 'Send request', onPressed: null), const SizedBox(height: 12), Text("We'll reply to ${widget.email ?? 'your email'}, usually within 2 business days.", style: AppTypography.caption)])));
}
