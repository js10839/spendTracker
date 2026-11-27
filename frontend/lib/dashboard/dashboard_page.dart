import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../calendar/calendar_dates.dart';
import '../data/payment_methods/payment_method_repository.dart';
import '../design_system/closing_day_picker.dart';
import '../design_system/components.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../home/home_format.dart';
import '../home/widgets/home_month_sheet.dart';
import '../onboarding/onboarding_card_color.dart';
import '../onboarding/widgets/onboarding_custom_card_sheet.dart';
import 'dashboard_analytics.dart';
import 'dashboard_motion.dart';
import 'dashboard_preview_data.dart';
import 'dashboard_period_switch.dart';
import 'dashboard_repository.dart';
import 'dashboard_statement_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.isMember,
    required this.onHome,
    required this.onProfile,
  });

  final bool isMember;
  final VoidCallback onHome;
  final VoidCallback onProfile;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _carousel = PageController(viewportFraction: .895);
  late Future<DashboardSummary> _summary;
  late Future<DashboardSummary> _period;
  Future<DashboardSummary>? _rollingPeriod;
  bool _showRolling = false;
  bool _rollingToggle = false;
  late Future<Map<DateTime, int>?> _income;
  late Future<List<DashboardCashMonth>?> _cashFlow;
  late DateTime _month;
  DateTime get _today =>
      widget.isMember ? calendarDate(DateTime.now()) : dashboardGuestToday;
  DateTime get _currentMonth => DateTime.utc(_today.year, _today.month);
  var _cardIndex = 0;
  var _addingCard = false;

  @override
  void initState() {
    super.initState();
    _month = _currentMonth;
    _refreshData();
  }

  @override
  void dispose() {
    _carousel.dispose();
    super.dispose();
  }

  Future<DashboardSummary> _load(DateTime month) {
    if (!widget.isMember) {
      return SynchronousFuture(dashboardGuestSummary(month));
    }
    final repository = DashboardRepository.instance;
    if (repository == null) {
      return Future.error(StateError('Dashboard API is not configured'));
    }
    return repository.load(_today, month: month);
  }

  Future<DashboardSummary> _loadRolling() async {
    if (!widget.isMember) {
      return dashboardGuestSummary(_currentMonth, rolling: true);
    }
    final repository = DashboardRepository.instance;
    if (repository == null) throw StateError('Dashboard API is not configured');
    return repository.loadPast30Days(_today);
  }

  void _togglePeriod() {
    setState(() {
      _rollingToggle = !_rollingToggle;
    });
  }

  void _applyPeriod() {
    if (_showRolling == _rollingToggle) return;
    setState(() {
      _showRolling = _rollingToggle;
      if (_showRolling) _rollingPeriod ??= _loadRolling();
    });
  }

  Future<Map<DateTime, int>?> _loadIncome() async {
    if (!widget.isMember) return dashboardGuestIncome();
    try {
      return await DashboardRepository.instance?.loadReceivedIncome(_today);
    } catch (_) {
      return null;
    }
  }

  Future<List<DashboardCashMonth>?> _loadCashFlow(
    DateTime month,
    Future<DashboardSummary> period,
    Future<Map<DateTime, int>?> receivedIncome,
  ) async {
    try {
      final summary = await period;
      final income = await receivedIncome;
      if (income == null) return null;
      final first = DateTime.utc(month.year, month.month - 5);
      final previous = first.year < month.year ? await _load(first) : null;
      final spending = {
        for (final bucket in previous?.yearly ?? const <DashboardBucket>[])
          bucket.date: bucket.cents,
        for (final bucket in summary.yearly) bucket.date: bucket.cents,
      };
      return [
            for (var offset = 0; offset < 6; offset++)
              DateTime.utc(first.year, first.month + offset),
          ]
          .map(
            (date) => (
              date: date,
              income: income[date] ?? 0,
              spending: spending[date] ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  void _refreshData() {
    _summary = _load(_currentMonth);
    _period = _month == _currentMonth ? _summary : _load(_month);
    _rollingPeriod = _showRolling ? _loadRolling() : null;
    _income = _loadIncome();
    _cashFlow = _loadCashFlow(_month, _period, _income);
  }

  void _reload() {
    if (_carousel.hasClients) _carousel.jumpToPage(0);
    setState(() {
      _cardIndex = 0;
      _refreshData();
    });
  }

  void _selectMonth(DateTime date) {
    final month = DateTime.utc(date.year, date.month);
    if (month == _month || month.year < 2 || month.year > 9997) return;
    setState(() {
      _month = month;
      _period = month == _currentMonth ? _summary : _load(month);
      _cashFlow = _loadCashFlow(month, _period, _income);
    });
  }

  Future<void> _pickMonth() async {
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HomeMonthSheet(
        initialMonth: _month,
        maxHeight: MediaQuery.sizeOf(context).height * .75,
        showPreviewTotals: false,
      ),
    );
    if (mounted && selected != null) _selectMonth(selected);
  }

  Future<void> _addCard() async {
    if (!widget.isMember) {
      await context.push('/login', extra: dashboardDetailOrigin);
      return;
    }

    final name = await pushDashboardDetail<String>(
      context,
      title: 'Add a card',
      builder: (_) => const OnboardingCustomCardSheet(),
    );
    if (name == null || !mounted) return;

    int? selectedDay;
    final day = await pushDashboardDetail<int>(
      context,
      title: 'Statement closing day',
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                AppClosingDayPicker(
                  selectedDay: selectedDay,
                  onSelected: (day) => setSheetState(() => selectedDay = day),
                  today: DateTime.now(),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save card',
                  onPressed: selectedDay == null
                      ? null
                      : () => Navigator.of(context).pop(selectedDay),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (day == null || !mounted) return;

    setState(() => _addingCard = true);
    try {
      await PaymentMethodRepository.instance.createCreditCard(
        name: name,
        closingDay: day,
        color: onboardingCardColor(name),
      );
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save card. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingCard = false);
    }
  }

  void _openStatement(DashboardStatement statement) {
    final start = DashboardStatementCard.shortDate(statement.start);
    final end = DashboardStatementCard.shortDate(statement.end);
    pushDashboardDetail<void>(
      context,
      title: statement.name,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Cycle $start – $end', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            Text(
              formatHomeMoney(statement.totalCents),
              style: AppTypography.heading1,
            ),
            if (statement.topCategories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Top categories', style: AppTypography.bodyMediumStrong),
              for (final category in statement.topCategories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category.name, style: AppTypography.bodyMedium),
                  trailing: Text(
                    formatHomeMoney(category.amountCents),
                    style: AppTypography.bodyMediumStrong,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: AppTokens.brandPurple,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Hero(
                tag: dashboardHeaderHero,
                curve: dashboardEaseInOut,
                flightShuttleBuilder: dashboardSurfaceFlight,
                child: Material(
                  color: AppTokens.brandPurple,
                  child: FutureBuilder<DashboardSummary>(
                    future: _summary,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.fiveXL),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTokens.textInverse,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Text(
                                'Couldn’t load the dashboard.',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppTokens.textInverse,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppButton(label: 'Try again', onPressed: _reload),
                            ],
                          ),
                        );
                      }
                      return _header(context, snapshot.data!);
                    },
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppTokens.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.threeXL,
                  ),
                  child: Column(
                    spacing: AppSpacing.md,
                    children: [
                      DashboardPeriodSwitch(
                        rolling: _rollingToggle,
                        today: _today,
                        month: _month,
                        onToggle: _togglePeriod,
                        onSettled: _applyPeriod,
                        onPickMonth: _pickMonth,
                        onPreviousMonth: () => _selectMonth(
                          DateTime.utc(_month.year, _month.month - 1),
                        ),
                        onNextMonth: () => _selectMonth(
                          DateTime.utc(_month.year, _month.month + 1),
                        ),
                      ),
                      FutureBuilder<DashboardSummary>(
                        future: _showRolling ? _rollingPeriod : _period,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final data = snapshot.data;
                          if (data == null) {
                            return Column(
                              children: [
                                Text(
                                  _showRolling
                                      ? 'Couldn’t load the past 30 days.'
                                      : 'Couldn’t load this month.',
                                  style: AppTypography.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: _reload,
                                  child: const Text('Try again'),
                                ),
                              ],
                            );
                          }
                          return DashboardAnalytics(
                            key: ValueKey((_month, _showRolling)),
                            rolling: _showRolling,
                            summary: data,
                            cashFlow: _cashFlow,
                            onRetryCashFlow: () => setState(() {
                              _income = _loadIncome();
                              _cashFlow = _loadCashFlow(
                                _month,
                                _period,
                                _income,
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(color: AppTokens.background),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: AppTokens.background,
        child: SafeArea(
          top: false,
          child: AppBottomNavigation(
            selectedIndex: 1,
            onSelected: (index) {
              if (index == 0) widget.onHome();
              if (index == 4) widget.onProfile();
            },
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context, DashboardSummary summary) {
    final statements = summary.statements;
    final itemCount = statements.length + 1;
    final scaled = MediaQuery.textScalerOf(context).scale(28);
    final cardHeight = 208.0 + (scaled - 28).clamp(0.0, double.infinity) * 5;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xl),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showRolling ? 'Past 30 days' : 'Spent this month',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTokens.textInverse.withValues(alpha: .7),
                    ),
                  ),
                ),
                Text(
                  formatHomeMoney(
                    _showRolling
                        ? summary.rollingSpendingCents
                        : summary.monthlySpendingCents,
                  ),
                  style: AppTypography.displayAmount.copyWith(
                    color: AppTokens.textInverse,
                    fontSize: 20,
                    letterSpacing: -.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xl),
            child: SizedBox(
              height: cardHeight,
              child: PageView.builder(
                key: const Key('dashboard-statement-carousel'),
                controller: _carousel,
                padEnds: false,
                itemCount: itemCount,
                onPageChanged: (index) => setState(() => _cardIndex = index),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: index < statements.length
                      ? DashboardStatementCard(
                          statement: statements[index],
                          onTap: () => _openStatement(statements[index]),
                        )
                      : _AddCardTile(onTap: _addingCard ? null : _addCard),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPageIndicator(
            count: itemCount,
            activeIndex: _cardIndex.clamp(0, itemCount - 1).toInt(),
            color: AppTokens.textPrimary,
            inactiveColor: AppTokens.borderSubtle,
          ),
        ],
      ),
    );
  }
}

class _AddCardTile extends StatelessWidget {
  const _AddCardTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTokens.surface,
    shape: const RoundedRectangleBorder(
      side: BorderSide(width: 1.5, color: AppTokens.borderSubtle),
      borderRadius: BorderRadius.all(Radius.circular(AppSpacing.twoXL)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: AppSpacing.fiveXL,
            height: AppSpacing.fiveXL,
            decoration: const BoxDecoration(
              color: AppTokens.brandLime,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset('assets/dashboard/add_card.svg'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Add a card', style: AppTypography.bodyMediumStrong),
          Text(
            'Credit card',
            style: AppTypography.caption.copyWith(
              color: AppTokens.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}
