import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/components.dart';
import '../design_system/tokens.dart';
import 'widgets/home_calendar.dart';
import 'widgets/home_header.dart';
import 'home_preview_data.dart';
import 'widgets/home_search_results.dart';
import 'widgets/home_transaction_section.dart';
import 'widgets/home_filter_sheet.dart';
import 'widgets/home_month_sheet.dart';
import 'widgets/home_note_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  /// 날짜와 카드별 보기 상태를 유지한다.
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
  final Map<DateTime, String> _notes = {
    DateTime(2026, 8, 24): HomePreviewData.initialNote,
  };
  final Map<(DateTime, String), String> _merchantNotes = {};
  final TextEditingController _search = TextEditingController();
  final ScrollController _calendarScroll = ScrollController();
  final GlobalKey _daySummaryAnchor = GlobalKey();

  static const _addTooltipSeenKey = 'home_add_tooltip_seen';
  static const _addTooltipDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _showFirstVisitTooltip();
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
    _addTooltipTimer?.cancel();
    _search.dispose();
    _calendarScroll.dispose();
    super.dispose();
  }

  @override
  /// 선택 카드의 색을 상태 표시줄과 홈 헤더에 함께 적용한다.
  Widget build(BuildContext context) {
    final color = switch (_totalMode) {
      HomeTotalMode.spending => HomePreviewData.cardColors[_card],
      HomeTotalMode.net => Colors.black,
      HomeTotalMode.income => AppPalette.lime600,
    };
    final header = HomeHeader(
      amount: HomePreviewData.amounts[_card],
      income: HomePreviewData.incomeFor(_card),
      totalMode: _totalMode,
      onTotalTap: () => setState(() => _totalMode = HomeTotalMode.values[(_totalMode.index + 1) % HomeTotalMode.values.length]),
      card: _card,
      view: _view,
      month: _month,
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
      onMoveMonth: _moveMonth,
      onOpenSearch: () => setState(() => _showSearch = true),
      onCancelSearch: _cancelSearch,
      onSearchChanged: (_) => setState(() {}),
    );
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppTokens.background.withValues(alpha: 0),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
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
                          const AppBottomNavigation(selectedIndex: 0),
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
    setState(() {
      _showSearch = false;
      _searchCategory = 0;
    });
  }

  /// 홈 달력과 검색 또는 거래 영역을 하나의 스크롤 화면에 배치한다.
  Widget _calendarBody() {
    final calendar = HomeCalendar(
      month: _month,
      selectedDate: _selectedDate,
      card: _card,
      view: _view,
      showSearch: _showSearch,
      search: _search.text,
      onDateSelected: _selectDate,
    );
    return ListView(
      controller: _calendarScroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        14,
        AppSpacing.lg,
        AppSpacing.twoXL,
      ),
      children: [
        calendar,
        const SizedBox(height: AppSpacing.md),
        if (_showSearch && _search.text.trim().isNotEmpty)
          HomeSearchResults(
            search: _search.text,
            card: _card,
            month: _month,
            searchCategory: _searchCategory,
            onCategoryChanged: (value) =>
                setState(() => _searchCategory = value),
          )
        else ...[
          calendar.legend(),
          const SizedBox(height: AppSpacing.sm),
          KeyedSubtree(
            key: _daySummaryAnchor,
            child: HomeTransactionSection(
              selectedDate: _selectedDate,
              card: _card,
              view: _view,
              expanded: _expanded,
              expandedTransactions: _expandedTransactions,
              notes: _notes,
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

  /// 선택 날짜의 메모 시트를 열고 저장한 내용은 홈 미리보기 상태에 유지한다.
  Future<void> _openNoteEditor([String? merchant]) async {
    final date = DateUtils.dateOnly(_selectedDate);
    final merchantKey = (date, merchant ?? '');
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.background.withValues(alpha: 0),
      barrierColor: AppTokens.overlayDim,
      builder: (context) => HomeNoteSheet(
        date: date,
        initialText: merchant == null
            ? _notes[date] ?? ''
            : _merchantNotes[merchantKey] ?? '',
      ),
    );
    if (!mounted || note == null) return;
    setState(() {
      if (merchant == null) {
        _notes[date] = note;
      } else {
        _merchantNotes[merchantKey] = note;
      }
    });
  }

  /// 필터 시트를 열어 선택을 Show로 확정하고 버튼 강조를 닫는다.
  Future<void> _openFilter() async {
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
        initialSelection: _card,
        month: _month,
        maxHeight: MediaQuery.sizeOf(context).height - filterBottom - 16,
      ),
    );
    if (!mounted) return;
    setState(() {
      if (selected != null) {
        _card = selected;
        _expandedTransactions.clear();
      }
      _filterOpen = false;
    });
  }

  /// 월 넘김 뒤 선택일을 같은 월의 첫날로 맞춘다.
  void _moveMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selectedDate = DateTime(_month.year, _month.month, 1);
    _expanded = false;
    _expandedTransactions.clear();
  });

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
        initialMonth: _month,
        maxHeight: MediaQuery.sizeOf(context).height - monthBottom - 16,
      ),
    );
    if (!mounted) return;
    setState(() {
      _monthPickerOpen = false;
      if (picked != null) {
        _month = picked;
        _selectedDate = DateTime(picked.year, picked.month, 1);
        _expanded = false;
        _expandedTransactions.clear();
      }
    });
  }
}
