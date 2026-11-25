import 'dart:async';

import 'calendar_data_source.dart';
import 'calendar_dates.dart';
import 'calendar_models.dart';

const _unchanged = Object();

/// Local interaction state; business data and period bounds come from FastAPI.
class CalendarState {
  CalendarState({
    required this.selectedDate,
    this.period,
    this.selectedCardId,
    this.isLoading = false,
    this.error,
    this.previousPeriod,
    this.nextPeriod,
  });

  final CalendarPeriod? period;
  final DateTime selectedDate;
  final String? selectedCardId;
  final bool isLoading;
  final Object? error;
  final CalendarPeriod? previousPeriod;
  final CalendarPeriod? nextPeriod;

  /// Null until the backend has resolved the initial period.
  CalendarWindow? get window => period?.window;
  List<CalendarPaymentMethod> get paymentMethods =>
      period?.paymentMethods ?? const [];
  List<CalendarPaymentMethod> get cards => period?.cards ?? const [];
  Map<DateTime, CalendarDay> get days =>
      isLoading || error != null ? const {} : period?.days ?? const {};
  CalendarDay? get selectedDay => days[selectedDate];

  CalendarState _copy({
    DateTime? selectedDate,
    CalendarPeriod? period,
    Object? selectedCardId = _unchanged,
    bool? isLoading,
    Object? error = _unchanged,
    Object? previousPeriod = _unchanged,
    Object? nextPeriod = _unchanged,
  }) => CalendarState(
    selectedDate: selectedDate ?? this.selectedDate,
    period: period ?? this.period,
    selectedCardId: identical(selectedCardId, _unchanged)
        ? this.selectedCardId
        : selectedCardId as String?,
    isLoading: isLoading ?? this.isLoading,
    error: identical(error, _unchanged) ? this.error : error,
    previousPeriod: identical(previousPeriod, _unchanged) ? this.previousPeriod : previousPeriod as CalendarPeriod?,
    nextPeriod: identical(nextPeriod, _unchanged) ? this.nextPeriod : nextPeriod as CalendarPeriod?,
  );
}

/// Bind these actions to the future UI. No billing rules or data aggregation.
class CalendarController {
  CalendarController({
    required this.ledgerId,
    required CalendarDataSource dataSource,
    DateTime Function()? clock,
    this.prefetchAdjacent = true,
  }) : _source = dataSource,
       _clock = clock ?? DateTime.now {
    _anchor = calendarDate(_clock());
    _state = CalendarState(selectedDate: _anchor);
  }

  final String ledgerId;
  final CalendarDataSource _source;
  final DateTime Function() _clock;
  final bool prefetchAdjacent;
  final Map<DateTime, CalendarPeriod> _cache = {};
  final Map<DateTime, Future<CalendarPeriod>> _pending = {};
  int _generation = 0;
  bool _navigating = false;
  final _changes = StreamController<CalendarState>.broadcast();
  late CalendarState _state;
  late DateTime _anchor;
  int _request = 0;
  bool _disposed = false;

  CalendarState get state => _state;
  Stream<CalendarState> get changes => _changes.stream;

  void _checkActive() {
    if (_disposed) throw StateError('CalendarController has been disposed');
  }

  void _emit(CalendarState state) {
    _state = state;
    _changes.add(state);
  }

  /// 변경된 거래나 메모를 반영하기 위해 세 기간을 모두 새로 조회한다.
  Future<void> refresh() {
    _resetCache();
    return _load(_anchor);
  }

  /// 이전 필터와 진행 중인 미리 조회 결과를 폐기한다.
  void _resetCache() {
    _generation++;
    _navigating = false;
    _cache.clear();
    _pending.clear();
  }

  /// 서버가 준 날짜 범위에 포함되는 캐시 응답을 찾는다.
  CalendarPeriod? _cached(DateTime anchor) {
    for (final period in _cache.values) {
      if (period.window.contains(anchor)) return period;
    }
    return null;
  }

  /// 같은 기간의 중복 요청은 하나의 Future를 공유한다.
  Future<CalendarPeriod> _fetch(DateTime anchor, String? card) {
    final date = calendarDate(anchor);
    final pending = _pending[date];
    if (pending != null) return pending;
    final future = _source.loadCalendar(ledgerId: ledgerId, anchorDate: date, paymentMethodId: card);
    _pending[date] = future;
    future.then((_) { if (identical(_pending[date], future)) _pending.remove(date); }, onError: (Object _) { if (identical(_pending[date], future)) _pending.remove(date); });
    return future;
  }

  /// 현재 기간에 인접한 응답만 유지하고 미리 조회한다.
  void _prepareAdjacent(CalendarPeriod current) {
    if (!prefetchAdjacent) return;
    final previous = current.previousAnchorDate;
    final next = current.nextAnchorDate;
    _cache.removeWhere((_, value) => value != current && !value.window.contains(previous) && !value.window.contains(next));
    _emit(_state._copy(previousPeriod: _cached(previous), nextPeriod: _cached(next)));
    final generation = _generation;
    for (final anchor in [previous, next]) {
      if (_cached(anchor) != null) continue;
      final card = current.paymentMethodId;
      unawaited(_fetch(anchor, card).then((period) {
        if (_disposed || generation != _generation || _state.period != current || period.paymentMethodId != card || !period.window.contains(anchor)) return;
        _cache[period.window.start] = period;
        _emit(_state._copy(previousPeriod: _cached(previous), nextPeriod: _cached(next)));
      }, onError: (Object _) {}));
    }
  }

  /// 서버가 반환한 기간으로 이동하고 새 인접 기간을 준비한다.
  void _activate(CalendarPeriod period, DateTime anchor, {required bool navigation}) {
    _anchor = calendarDate(anchor);
    _cache[period.window.start] = period;
    final preferred = navigation ? calendarDate(_clock()) : _state.selectedDate;
    _emit(_state._copy(period: period, selectedCardId: period.paymentMethodId, selectedDate: period.window.contains(preferred) ? preferred : period.window.start, isLoading: false, error: null, previousPeriod: null, nextPeriod: null));
    _prepareAdjacent(period);
  }

  Future<void> _load(DateTime anchor, {bool navigation = false}) async {
    _checkActive();
    _navigating = false;
    _anchor = calendarDate(anchor);
    final request = ++_request;
    final card = _state.selectedCardId;
    _emit(_state._copy(isLoading: true, error: null, previousPeriod: null, nextPeriod: null));
    try {
      final period = await _source.loadCalendar(
        ledgerId: ledgerId,
        anchorDate: _anchor,
        paymentMethodId: card,
      );
      if (_disposed || request != _request) return;
      _activate(period, anchor, navigation: navigation);
    } catch (error) {
      if (!_disposed && request == _request) {
        _emit(_state._copy(isLoading: false, error: error));
      }
    }
  }

  /// Null selects All. Backend validates the requested card and its ownership.
  Future<void> selectCard(String? id) {
    _checkActive();
    if (id == _state.selectedCardId && _state.error == null) {
      return Future.value();
    }
    _resetCache();
    _emit(_state._copy(selectedCardId: id, previousPeriod: null, nextPeriod: null));
    return _load(_state.selectedDate);
  }

  /// 서버가 제공한 이전 기간을 캐시 우선으로 연다.
  Future<void> previousPeriod() => _move(forward: false);

  /// 서버가 제공한 다음 기간을 캐시 우선으로 연다.
  Future<void> nextPeriod() => _move(forward: true);

  /// 아직 없는 인접 기간만 준비하고 화면 이동은 호출자에게 맡긴다.
  Future<bool> prepareAdjacent({required bool forward}) async {
    _checkActive();
    final current = _state.period;
    if (_state.isLoading || _state.error != null || current == null || _navigating) return false;
    final anchor = forward ? current.nextAnchorDate : current.previousAnchorDate;
    if (_cached(anchor) != null) return true;
    _navigating = true;
    final generation = _generation;
    final request = ++_request;
    try {
      final target = await _fetch(anchor, _state.selectedCardId);
      if (_disposed || generation != _generation || request != _request || _state.period != current || !target.window.contains(anchor)) return false;
      _cache[target.window.start] = target;
      _emit(_state._copy(previousPeriod: _cached(current.previousAnchorDate), nextPeriod: _cached(current.nextAnchorDate)));
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation && request == _request) _emit(_state._copy(error: error));
      return false;
    } finally {
      if (generation == _generation && request == _request) _navigating = false;
    }
  }

  /// 인접 응답이 없으면 현재 화면을 유지한 채 요청 완료를 기다린다.
  Future<void> _move({required bool forward}) async {
    _checkActive();
    final period = _state.period;
    if (_state.isLoading || _state.error != null || period == null || _navigating) return;
    final anchor = forward ? period.nextAnchorDate : period.previousAnchorDate;
    final cached = _cached(anchor);
    if (cached != null) { _activate(cached, anchor, navigation: true); return; }
    _navigating = true;
    final generation = _generation;
    final request = ++_request;
    try {
      final target = await _fetch(anchor, _state.selectedCardId);
      if (!_disposed && generation == _generation && request == _request && target.window.contains(anchor)) _activate(target, anchor, navigation: true);
    } catch (error) {
      if (!_disposed && generation == _generation && request == _request) _emit(_state._copy(error: error));
    } finally {
      if (generation == _generation && request == _request) _navigating = false;
    }
  }

  Future<void> jumpToDate(DateTime date) {
    _checkActive();
    final day = calendarDate(date);
    if (!_state.isLoading &&
        _state.error == null &&
        (_state.window?.contains(day) ?? false)) {
      selectDate(day);
      return Future.value();
    }
    _emit(_state._copy(selectedDate: day));
    return _load(day);
  }

  Future<void> goToToday() => jumpToDate(_clock());

  /// A date click only selects an already-loaded server day.
  void selectDate(DateTime date) {
    _checkActive();
    if (!(_state.window?.contains(date) ?? false)) {
      throw ArgumentError(
        'Use jumpToDate to select outside the current window',
      );
    }
    _emit(_state._copy(selectedDate: calendarDate(date)));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resetCache();
    _request++;
    unawaited(_changes.close());
  }
}
