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
    this.isSavingNote = false,
    this.noteError,
  });

  final CalendarPeriod? period;
  final DateTime selectedDate;
  final String? selectedCardId;
  final bool isLoading;
  final Object? error;
  final bool isSavingNote;
  final Object? noteError;

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
    bool? isSavingNote,
    Object? noteError = _unchanged,
  }) => CalendarState(
    selectedDate: selectedDate ?? this.selectedDate,
    period: period ?? this.period,
    selectedCardId: identical(selectedCardId, _unchanged)
        ? this.selectedCardId
        : selectedCardId as String?,
    isLoading: isLoading ?? this.isLoading,
    error: identical(error, _unchanged) ? this.error : error,
    isSavingNote: isSavingNote ?? this.isSavingNote,
    noteError: identical(noteError, _unchanged) ? this.noteError : noteError,
  );
}

/// Bind these actions to the future UI. No billing rules or data aggregation.
class CalendarController {
  CalendarController({
    required this.ledgerId,
    required CalendarDataSource dataSource,
    DateTime Function()? clock,
  }) : _source = dataSource,
       _clock = clock ?? DateTime.now {
    _anchor = calendarDate(_clock());
    _state = CalendarState(selectedDate: _anchor);
  }

  final String ledgerId;
  final CalendarDataSource _source;
  final DateTime Function() _clock;
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

  Future<void> refresh() => _load(_anchor);

  Future<void> _load(DateTime anchor, {bool navigation = false}) async {
    _checkActive();
    _anchor = calendarDate(anchor);
    final request = ++_request;
    final card = _state.selectedCardId;
    _emit(_state._copy(isLoading: true, error: null));
    try {
      final period = await _source.loadCalendar(
        ledgerId: ledgerId,
        anchorDate: _anchor,
        paymentMethodId: card,
      );
      if (_disposed || request != _request) return;
      final preferred = navigation
          ? calendarDate(_clock())
          : _state.selectedDate;
      _emit(
        _state._copy(
          period: period,
          selectedCardId: period.paymentMethodId,
          selectedDate: period.window.contains(preferred)
              ? preferred
              : period.window.start,
          isLoading: false,
          error: null,
        ),
      );
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
    _emit(_state._copy(selectedCardId: id));
    return _load(_state.selectedDate);
  }

  /// Wait for each destination before using its navigation anchors again.
  Future<void> previousPeriod() => _move(forward: false);
  Future<void> nextPeriod() => _move(forward: true);

  Future<void> _move({required bool forward}) {
    _checkActive();
    final period = _state.period;
    if (_state.isLoading || _state.error != null || period == null) {
      return Future.value();
    }
    return _load(
      forward ? period.nextAnchorDate : period.previousAnchorDate,
      navigation: true,
    );
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

  Future<bool> saveSelectedNote(String content) async {
    _checkActive();
    if (_state.isSavingNote) throw StateError('A note save is already pending');
    final date = _state.selectedDate;
    _emit(_state._copy(isSavingNote: true, noteError: null));
    try {
      await _source.saveNote(ledgerId: ledgerId, date: date, content: content);
      if (_disposed) return true;
      _emit(_state._copy(isSavingNote: false, noteError: null));
      await refresh();
      return true;
    } catch (error) {
      if (!_disposed) {
        _emit(_state._copy(isSavingNote: false, noteError: error));
      }
      return false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _request++;
    unawaited(_changes.close());
  }
}
