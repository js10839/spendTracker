import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calendar/calendar_access.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_models.dart';
import '../data/transactions/transaction_search.dart';
import '../design_system/components.dart';
import '../design_system/typography.dart';
import 'home_format.dart';
import '../design_system/tokens.dart';
import 'widgets/home_calendar.dart';
import 'widgets/home_header.dart';
import 'home_preview_data.dart';
import 'home_transaction_data.dart';
import 'widgets/home_search_results.dart';
import 'widgets/home_transaction_section.dart';
import 'widgets/home_filter_sheet.dart';
import 'widgets/home_month_sheet.dart';
import 'widgets/home_note_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.isMember = false});

  final bool isMember;

  @override
  /// 날짜와 카드별 보기 상태를 유지한다.
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CalendarController? _calendarController;
  StreamSubscription<CalendarState>? _calendarSubscription;
  CalendarState? _calendarState;
  Map<String, String> _categories = {};
  bool _calendarOpening = false;
  bool _calendarOpenFailed = false;
  TransactionSearchResult? _searchResult;
  Timer? _searchTimer;
  int _searchRequest = 0;
  bool _searchLoading = false;
  bool _searchFailed = false;
  String? _searchPeriodKey;
  DateTime _month = DateTime(2026, 8);
  DateTime _selectedDate = DateTime(2026, 8, 24);
  int _card = 0;
  int _view = 1;
  HomeTotalMode _totalMode = HomeTotalMode.spending;
  bool _showSearch = false;
  int _searchCategory = 0;
  bool _expanded = false;
  final Set<int> _expandedTransactions = {};
  bool _filterOpen = false;
  bool _monthPickerOpen = false;
  bool _showAddTooltip = false;
  Timer? _addTooltipTimer;
  final LayerLink _filterLink = LayerLink();
  final LayerLink _monthLink = LayerLink();
  final GlobalKey _filterAnchorKey = GlobalKey();
  final GlobalKey _monthAnchorKey = GlobalKey();
  double _monthControlWidth = 0;
  final Map<(DateTime, String), String> _merchantNotes = {
    (DateTime(2026, 8, 24), '0'): HomePreviewData.initialNote,
  };
  final TextEditingController _search = TextEditingController();
  final ScrollController _calendarScroll = ScrollController();
  final GlobalKey _daySummaryAnchor = GlobalKey();
  final GlobalKey<AppCalendarPagerState> _calendarPagerKey = GlobalKey<AppCalendarPagerState>();

  static const _addTooltipSeenKey = 'home_add_tooltip_seen';
  static const _addTooltipDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _showFirstVisitTooltip();
    if (widget.isMember) _openCalendar();
  }

  /// 회원의 가계부를 조회하고 달력 상태 변경을 구독한다.
  Future<void> _openCalendar() async {
    setState(() { _calendarOpening = true; _calendarOpenFailed = false; });
    try {
      final access = CalendarAccess.instance;
      if (access == null) throw StateError('Calendar API is not configured');
      final categories = await access.loadCategoryNames();
      final controller = await access.open();
      if (!mounted) { controller.dispose(); return; }
      await _calendarSubscription?.cancel();
      _calendarController?.dispose();
      _calendarController = controller;
      _calendarSubscription = controller.changes.listen((state) {
        if (!mounted) return;
        setState(() => _calendarState = state);
        if (_showSearch && _search.text.trim().isNotEmpty) {
          if (state.isLoading) {
            _invalidateSearch();
          } else if (state.error == null && state.window != null) {
            final key = '${state.window!.start}/${state.window!.endInclusive}/${state.selectedCardId}';
            if (_searchPeriodKey != key) _scheduleSearch();
          }
        }
      });
      setState(() { _categories = categories; _calendarState = controller.state; _calendarOpening = false; });
    } catch (_) {
      if (mounted) setState(() { _calendarOpenFailed = true; _calendarOpening = false; });
    }
  }

  /// 회원 필터 색상은 서버가 저장한 결제수단 색상을 사용한다.
  Color _memberBackground(CalendarState state) {
    final methods = state.paymentMethods.where((method) => method.id == state.selectedCardId);
    if (methods.isEmpty || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(methods.first.color)) return AppTokens.brandPurple;
    return Color(int.parse('FF${methods.first.color.substring(1)}', radix: 16));
  }

  /// 서버의 사이클 범위를 월 전환 컨트롤에 표시한다.
  String _memberRangeLabel(CalendarState state) {
    final start = state.window!.start;
    final end = state.window!.endInclusive;
    if (start.year == end.year && start.month == end.month) return '${homeMonths[start.month - 1]} ${start.year}';
    if (start.year == end.year) return '${homeMonths[start.month - 1]} - ${homeMonths[end.month - 1]} ${end.year}';
    return '${homeMonths[start.month - 1]} ${start.year} - ${homeMonths[end.month - 1]} ${end.year}';
  }

  /// 데이터 조회 실패 시 기존 버튼으로 다시 시도한다.
  Widget _calendarError(VoidCallback retry) => Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Unable to load your calendar.', style: AppTypography.bodyMedium), const SizedBox(height: AppSpacing.md), AppButton(label: 'Try again', onPressed: retry)])));

  /// 대기 중인 검색과 이전 결과가 새 조건에 반영되지 않게 한다.
  void _invalidateSearch() {
    _searchTimer?.cancel();
    _searchRequest++;
    _searchResult = null;
    _searchLoading = false;
    _searchFailed = false;
    _searchPeriodKey = null;
  }

  /// 입력이 잠시 멈춘 뒤 현재 달력 기간과 결제수단을 검색한다.
  void _scheduleSearch() {
    _invalidateSearch();
    final state = _calendarState;
    final query = _search.text.trim();
    if (!widget.isMember || !_showSearch || query.isEmpty || state?.window == null || state!.isLoading || state.error != null) return;
    final key = '${state.window!.start}/${state.window!.endInclusive}/${state.selectedCardId}';
    _searchPeriodKey = key;
    final request = _searchRequest;
    setState(() => _searchLoading = true);
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await CalendarAccess.instance!.searchTransactions(_calendarController!.ledgerId, state.window!.start, state.window!.endInclusive, query, state.selectedCardId);
        if (!mounted || request != _searchRequest) return;
        setState(() { _searchResult = result; _searchLoading = false; });
      } catch (_) {
        if (!mounted || request != _searchRequest) return;
        setState(() { _searchLoading = false; _searchFailed = true; });
      }
    });
  }

  /// 검색 거래 ID와 달력 거래의 결제수단을 연결한다.
  Map<String, Color> _searchMethodColors(CalendarState state) {
    final colors = {for (final method in state.paymentMethods) method.id: method.color};
    final result = <String, Color>{};
    for (final day in state.days.values) {
      for (final transaction in day.transactions) {
        final color = colors[transaction.paymentMethodId];
        if (color != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) result[transaction.id] = Color(int.parse('FF${color.substring(1)}', radix: 16));
      }
    }
    return result;
  }

  /// 기기에 첫 표시 여부를 저장해 안내 말풍선이 다시 뜨지 않게 한다.
  Future<void> _showFirstVisitTooltip() async {
    // TODO: 지출 입력 화면 연결 시 3초 타이머를 없애고 첫 진입 1회 노출은 유지한다.
    // + 버튼은 툴팁을 닫고 입력 화면으로 이동하며, 화면의 다른 곳을 터치해도 닫는다.
    // 표시 완료는 노출 시점이 아닌 닫는 시점에 저장해 중도 종료 시 다시 안내한다.
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || (preferences.getBool(_addTooltipSeenKey) ?? false)) return;
    await preferences.setBool(_addTooltipSeenKey, true);
    if (!mounted) return;
    setState(() => _showAddTooltip = true);
    _addTooltipTimer = Timer(_addTooltipDuration, () {
      if (mounted) setState(() => _showAddTooltip = false);
    });
  }

  @override
  /// 검색 입력 컨트롤러를 화면과 함께 정리한다.
  void dispose() {
    _searchTimer?.cancel();
    _searchRequest++;
    unawaited(_calendarSubscription?.cancel());
    _calendarController?.dispose();
    _addTooltipTimer?.cancel();
    _search.dispose();
    _calendarScroll.dispose();
    super.dispose();
  }

  @override
  /// 선택 카드의 색을 상태 표시줄과 홈 헤더에 함께 적용한다.
  Widget build(BuildContext context) {
    final state = _calendarState;
    if (widget.isMember && (_calendarOpening || (state?.period == null && state?.isLoading == true))) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (widget.isMember && (_calendarOpenFailed || state == null)) return Scaffold(body: _calendarError(_openCalendar));
    if (widget.isMember && state!.period == null) return Scaffold(body: _calendarError(_calendarController!.refresh));
    final methods = state?.paymentMethods.where((method) => method.id == state.selectedCardId);
    final color = switch (_totalMode) {
      HomeTotalMode.spending => widget.isMember ? _memberBackground(state!) : HomePreviewData.cardColors[_card],
      HomeTotalMode.net => Colors.black,
      HomeTotalMode.income => AppPalette.lime600,
    };
    // 서버가 집계한 날짜별 금액만 현재 조회 기간의 헤더 합계에 사용한다.
    final spending = widget.isMember ? state!.days.values.fold<int>(0, (total, day) => total + day.spendingCents) : HomePreviewData.amounts[_card];
    final income = widget.isMember ? state!.days.values.fold<int>(0, (total, day) => total + day.receivedIncomeCents) : HomePreviewData.incomeFor(_card);
    final header = HomeHeader(
      amount: spending,
      income: income,
      totalMode: _totalMode,
      onTotalTap: () => setState(() => _totalMode = HomeTotalMode.values[(_totalMode.index + 1) % HomeTotalMode.values.length]),
      card: _card,
      view: _view,
      month: widget.isMember ? state!.selectedDate : _month,
      showSearch: _showSearch,
      search: _search,
      filterLink: _filterLink,
      monthLink: _monthLink,
      filterAnchorKey: _filterAnchorKey,
      monthAnchorKey: _monthAnchorKey,
      monthControlWidth: _monthControlWidth,
      onViewChanged: (value) => setState(() {
        _view = value;
        _expanded = false;
        _expandedTransactions.clear();
      }),
      onOpenFilter: _openFilter,
      onOpenMonthPicker: _openMonthPicker,
      onMoveMonth: (delta) {
        final pager = _calendarPagerKey.currentState;
        if (pager == null) { _moveMonth(delta); } else { pager.move(delta); }
      },
      onOpenSearch: () => setState(() => _showSearch = true),
      onCancelSearch: _cancelSearch,
      onSearchChanged: (_) { setState(() {}); if (widget.isMember) _scheduleSearch(); },
      liveFilterName: widget.isMember ? (methods!.isEmpty ? 'All' : methods.first.name) : null,
      liveRangeLabel: widget.isMember ? _memberRangeLabel(state!) : null,
      liveSpendingLabel: widget.isMember && state!.period!.mode == 'card' ? '${state.window!.start.month}/${state.window!.start.day} – ${state.window!.endInclusive.month}/${state.window!.endInclusive.day}' : null,
      // 새 조회가 끝나기 전에는 이전 기간의 합계를 표시하지 않는다.
      hideExampleTotals: widget.isMember && (state!.isLoading || state.error != null),
      totalsEnabled: !widget.isMember || (!state!.isLoading && state.error == null),
      searchEnabled: true,
      onLightBackground: widget.isMember ? ThemeData.estimateBrightnessForColor(color) == Brightness.light : null,
    );
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppTokens.background.withValues(alpha: 0),
        statusBarIconBrightness: ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Brightness.dark : Brightness.light,
        statusBarBrightness: ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: color,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: Container(
                      key: const Key('home-calendar-sheet'),
                      decoration: const BoxDecoration(
                        color: AppTokens.background,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl),
                        ),
                      ),
                      child: _calendarBody(),
                    ),
                  ),
                  ColoredBox(
                    color: AppTokens.background,
                    child: SafeArea(
                      top: false,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          AppBottomNavigation(selectedIndex: 0, onSelected: (index) { if (index == 4) context.push('/profile', extra: widget.isMember); }),
                          if (_showAddTooltip &&
                              !_showSearch &&
                              keyboardInset == 0)
                            const Positioned(
                              bottom: 56,
                              child: AppCalloutTooltip(
                                key: Key('home-add-tooltip'),
                                message: "Enter today's spending",
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showSearch && keyboardInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: keyboardInset,
                // 반투명 iOS 키보드 뒤로 달력과 하단 바가 비치지 않게 한다.
                child: const IgnorePointer(
                  child: ColoredBox(
                    key: Key('home-search-keyboard-backdrop'),
                    color: AppTokens.background,
                  ),
                ),
              ),
            if (_filterOpen || _monthPickerOpen) ...[
              const Positioned.fill(
                child: ColoredBox(color: AppTokens.overlayDim),
              ),
              if (_filterOpen)
                CompositedTransformFollower(
                  link: _filterLink,
                  showWhenUnlinked: false,
                  child: IgnorePointer(
                    child: header.filterPill(
                      key: const Key('home-filter-highlight'),
                    ),
                  ),
                ),
              if (_monthPickerOpen)
                CompositedTransformFollower(
                  link: _monthLink,
                  showWhenUnlinked: false,
                  child: IgnorePointer(child: header.activeMonthSwitcher()),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 취소 시 검색어를 지우고 기존 월 선택 헤더와 날짜 요약을 복원한다.
  void _cancelSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
    _invalidateSearch();
    setState(() {
      _showSearch = false;
      _searchCategory = 0;
    });
  }

  /// 홈 달력과 검색 또는 거래 영역을 하나의 스크롤 화면에 배치한다.
  Widget _calendarBody() {
    final state = _calendarState;
    if (widget.isMember && state!.isLoading) return const Center(child: CircularProgressIndicator());
    if (widget.isMember && state!.error != null) return _calendarError(_calendarController!.refresh);
    final calendar = HomeCalendar(
      month: widget.isMember ? state!.selectedDate : _month,
      selectedDate: widget.isMember ? state!.selectedDate : _selectedDate,
      card: _card,
      view: _view,
      showSearch: _showSearch,
      search: _search.text,
      onDateSelected: _selectDate,
      liveState: widget.isMember ? state : null,
      matchedDates: widget.isMember && _showSearch ? _searchResult?.dates ?? const {} : const {},
    );
    // 현재 달력과 같은 위젯으로 인접 기간을 표시한다.
    HomeCalendar? adjacent(CalendarPeriod? period, int delta) {
      if (widget.isMember && period == null) return null;
      final month = widget.isMember ? period!.window.start : DateTime(_month.year, _month.month + delta);
      final adjacentState = widget.isMember ? CalendarState(selectedDate: month, period: period, selectedCardId: period!.paymentMethodId) : null;
      return HomeCalendar(month: month, selectedDate: month, card: _card, view: _view, showSearch: false, search: '', onDateSelected: (_) {}, liveState: adjacentState);
    }
    final previous = adjacent(state?.previousPeriod, -1);
    final next = adjacent(state?.nextPeriod, 1);
    return ListView(
      controller: _calendarScroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        14,
        AppSpacing.lg,
        AppSpacing.twoXL,
      ),
      children: [
        AppCalendarPager(
          key: _calendarPagerKey,
          current: calendar,
          currentHeight: calendar.gridHeight,
          previous: previous == null ? null : IgnorePointer(child: previous),
          previousHeight: previous?.gridHeight,
          next: next == null ? null : IgnorePointer(child: next),
          nextHeight: next?.gridHeight,
          onMove: _moveMonth,
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.isMember && _showSearch && _search.text.trim().isNotEmpty && _searchLoading)
          const Center(child: CircularProgressIndicator())
        else if (widget.isMember && _showSearch && _search.text.trim().isNotEmpty && _searchFailed)
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Unable to search. Please try again.', style: AppTypography.bodyMedium), const SizedBox(height: AppSpacing.md), AppButton(label: 'Try again', onPressed: _scheduleSearch)]))
        else if (_showSearch && _search.text.trim().isNotEmpty && (!widget.isMember || _searchResult != null))
          HomeSearchResults(
            search: _search.text,
            card: _card,
            month: _month,
            searchCategory: _searchCategory,
            onCategoryChanged: (value) =>
                setState(() => _searchCategory = value),
            liveResult: widget.isMember ? _searchResult : null,
            methodColors: widget.isMember ? _searchMethodColors(state!) : const {},
            rangeLabel: widget.isMember ? _memberRangeLabel(state!) : null,
          )
        else ...[
          calendar.legend(),
          const SizedBox(height: AppSpacing.sm),
          KeyedSubtree(
            key: _daySummaryAnchor,
            child: HomeTransactionSection(
              selectedDate: widget.isMember ? state!.selectedDate : _selectedDate,
              // 같은 거래 위젯에 회원의 서버 데이터 또는 게스트의 예시 데이터만 전달한다.
              transactions: widget.isMember ? memberHomeTransactions(state!.selectedDay, state.paymentMethods, _categories) : previewHomeTransactions(_selectedDate, _card),
              isToday: widget.isMember ? DateUtils.isSameDay(state!.selectedDate, DateTime.now()) : DateUtils.isSameDay(_selectedDate, DateTime(2026, 8, 24)),
              noteEditable: true,
              view: _view,
              expanded: _expanded,
              expandedTransactions: _expandedTransactions,
              merchantNotes: _merchantNotes,
              onExpand: () {
                setState(() => _expanded = true);
                _scrollToDaySummary();
              },
              onCollapse: () => setState(() => _expanded = false),
              onCollapseAll: () => setState(_expandedTransactions.clear),
              onToggleTransaction: (index) => setState(() {
                if (!_expandedTransactions.remove(index)) {
                  _expandedTransactions.add(index);
                }
              }),
              onOpenNoteEditor: _openNoteEditor,
            ),
          ),
        ],
      ],
    );
  }

  /// 날짜를 고르면 펼친 거래 카드가 하단 탐색바 위로 보이도록 스크롤한다.
  void _selectDate(DateTime date) {
    if (widget.isMember) _calendarController!.selectDate(date);
    setState(() {
      _selectedDate = date;
      _expanded = true;
      _expandedTransactions.clear();
    });
    if (_showSearch && _search.text.trim().isNotEmpty) return;
    _scrollToDaySummary();
  }

  /// 펼친 날짜 카드의 첫 거래가 탐색바 뒤에 가려지지 않게 스크롤한다.
  void _scrollToDaySummary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _daySummaryAnchor.currentContext;
      if (!mounted || anchor == null) return;
      Scrollable.ensureVisible(
        anchor,
        alignment: .3,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// 거래 ID로 메모를 저장하고 성공한 뒤 현재 달력을 갱신한다.
  Future<void> _openNoteEditor(HomeTransactionData transaction) async {
    final date = DateUtils.dateOnly(widget.isMember ? _calendarState!.selectedDate : _selectedDate);
    final key = (date, transaction.id);
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: !widget.isMember,
      enableDrag: !widget.isMember,
      backgroundColor: AppTokens.background.withValues(alpha: 0),
      barrierColor: AppTokens.overlayDim,
      builder: (context) => HomeNoteSheet(
        date: date,
        initialText: widget.isMember ? transaction.memo ?? '' : _merchantNotes[key] ?? '',
        onSave: widget.isMember ? (text) => CalendarAccess.instance!.updateTransactionMemo(_calendarController!.ledgerId, transaction.id, text) : null,
      ),
    );
    if (!mounted || note == null) return;
    if (widget.isMember) {
      await _calendarController!.refresh();
    } else {
      setState(() => _merchantNotes[key] = note);
    }
  }

  /// 필터 시트를 열어 선택을 Show로 확정하고 버튼 강조를 닫는다.
  Future<void> _openFilter() async {
    final state = _calendarState;
    final methods = widget.isMember ? state!.paymentMethods : null;
    final initialSelection = methods == null ? _card : methods.indexWhere((method) => method.id == state!.selectedCardId) + 1;
    final filterBox =
        _filterAnchorKey.currentContext!.findRenderObject()! as RenderBox;
    final filterBottom = filterBox
        .localToGlobal(Offset(0, filterBox.size.height))
        .dy;
    setState(() => _filterOpen = true);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.background.withValues(alpha: 0),
      barrierColor: AppTokens.background.withValues(alpha: 0),
      builder: (context) => HomeFilterSheet(
        initialSelection: initialSelection,
        month: widget.isMember ? state!.selectedDate : _month,
        methods: methods,
        maxHeight: MediaQuery.sizeOf(context).height - filterBottom - 16,
      ),
    );
    if (!mounted) return;
    setState(() {
      if (selected != null && !widget.isMember) {
        _card = selected;
        _expandedTransactions.clear();
      }
      _filterOpen = false;
    });
    if (selected != null && methods != null) {
      setState(() { _expanded = false; _expandedTransactions.clear(); });
      await _calendarController!.selectCard(selected == 0 ? null : methods[selected - 1].id);
    }
  }

  /// 월 넘김 뒤 선택일을 같은 월의 첫날로 맞춘다.
  void _moveMonth(int delta) async {
    if (widget.isMember) {
      setState(() { _expanded = false; _expandedTransactions.clear(); });
      final controller = _calendarController!;
      final currentPeriod = controller.state.period;
      final currentCard = controller.state.selectedCardId;
      final adjacent = delta < 0 ? controller.state.previousPeriod : controller.state.nextPeriod;
      if (adjacent == null) {
        final ready = await controller.prepareAdjacent(forward: delta > 0);
        if (!mounted || !ready) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || controller.state.period != currentPeriod || controller.state.selectedCardId != currentCard) return;
        final pager = _calendarPagerKey.currentState;
        if (pager != null) { await pager.move(delta); return; }
      }
      if (delta < 0) { await controller.previousPeriod(); } else { await controller.nextPeriod(); }
      return;
    }
    setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selectedDate = DateTime(_month.year, _month.month, 1);
    _expanded = false;
    _expandedTransactions.clear();
    });
  }

  /// 월 선택 시트를 열고 Done으로 확정한 월만 홈 달력에 반영한다.
  Future<void> _openMonthPicker() async {
    final monthBox =
        _monthAnchorKey.currentContext!.findRenderObject()! as RenderBox;
    final monthBottom = monthBox
        .localToGlobal(Offset(0, monthBox.size.height))
        .dy;
    setState(() {
      _monthControlWidth = monthBox.size.width;
      _monthPickerOpen = true;
    });
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.background.withValues(alpha: 0),
      barrierColor: AppTokens.background.withValues(alpha: 0),
      builder: (context) => HomeMonthSheet(
        initialMonth: widget.isMember ? _calendarState!.selectedDate : _month,
        showPreviewTotals: !widget.isMember,
        maxHeight: MediaQuery.sizeOf(context).height - monthBottom - 16,
      ),
    );
    if (!mounted) return;
    setState(() {
      _monthPickerOpen = false;
      if (picked != null && !widget.isMember) {
        _month = picked;
        _selectedDate = DateTime(picked.year, picked.month, 1);
        _expanded = false;
        _expandedTransactions.clear();
      }
    });
    if (picked != null && widget.isMember) {
      setState(() { _expanded = false; _expandedTransactions.clear(); });
      await _calendarController!.jumpToDate(picked);
    }
  }
}
