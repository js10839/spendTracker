import 'dart:async';

import 'calendar_data_source.dart';
import 'calendar_dates.dart';
import 'calendar_models.dart';
import 'calendar_projection.dart';

const _unchanged = Object();

/// Immutable state for a future StreamBuilder or other UI state adapter.
class CalendarState {
  CalendarState({
    required this.window,
    required this.selectedDate,
    this.selectedCardId,
    List<CalendarPaymentMethod> paymentMethods = const [],
    Map<DateTime, CalendarDay> days = const {},
    this.isLoading = false,
    this.error,
    this.isSavingNote = false,
    this.noteError,
  }) : paymentMethods = List.unmodifiable(paymentMethods),
       days = Map.unmodifiable(days);

  final CalendarWindow window;
  final DateTime selectedDate;

  /// Null is the dropdown's "All" option.
  final String? selectedCardId;
  final List<CalendarPaymentMethod> paymentMethods;
  final Map<DateTime, CalendarDay> days;
  final bool isLoading;
  final Object? error;
  final bool isSavingNote;
  final Object? noteError;

  List<CalendarPaymentMethod> get cards =>
      List.unmodifiable(paymentMethods.where((method) => method.isCredit));
  CalendarDay? get selectedDay => days[selectedDate];

  CalendarState _copy({
    CalendarWindow? window,
    DateTime? selectedDate,
    Object? selectedCardId = _unchanged,
    List<CalendarPaymentMethod>? paymentMethods,
    Map<DateTime, CalendarDay>? days,
    bool? isLoading,
    Object? error = _unchanged,
    bool? isSavingNote,
    Object? noteError = _unchanged,
  }) => CalendarState(
    window: window ?? this.window,
    selectedDate: selectedDate ?? this.selectedDate,
    selectedCardId: identical(selectedCardId, _unchanged)
        ? this.selectedCardId
        : selectedCardId as String?,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    days: days ?? this.days,
    isLoading: isLoading ?? this.isLoading,
    error: identical(error, _unchanged) ? this.error : error,
    isSavingNote: isSavingNote ?? this.isSavingNote,
    noteError: identical(noteError, _unchanged) ? this.noteError : noteError,
  );
}

/// No widgets, HTTP, or login. Supply a data source and bind actions to the UI.
/// Use one controller per ledger/session; dispose it on logout or ledger change.
class CalendarController {
  CalendarController({
    required this.ledgerId,
    required CalendarDataSource dataSource,
    DateTime Function()? clock,
  }) : _source = dataSource,
       _clock = clock ?? DateTime.now {
    final today = calendarDate(_clock());
    _state = CalendarState(
      window: CalendarWindow.containing(today),
      selectedDate: today,
    );
  }

  final String ledgerId;
  final CalendarDataSource _source;
  final DateTime Function() _clock;
  final _changes = StreamController<CalendarState>.broadcast();
  late CalendarState _state;
  int _request = 0;
  bool _disposed = false;

  CalendarState get state => _state;

  /// Read [state] for the initial snapshot; this stream emits subsequent changes.
  Stream<CalendarState> get changes => _changes.stream;

  void _checkActive() {
    if (_disposed) throw StateError('CalendarController has been disposed');
  }

  void _emit(CalendarState state) {
    _state = state;
    _changes.add(state);
  }

  int? get _closingDay => _state.selectedCardId == null
      ? null
      : _state.paymentMethods
            .firstWhere((method) => method.id == _state.selectedCardId)
            .closingDay;

  /// Initial load, manual retry, or reload after an external transaction edit.
  /// Window requests run in parallel. Failures are explicit, never empty days.
  Future<void> refresh() async {
    _checkActive();
    final request = ++_request;
    final snapshot = _state;
    _emit(_state._copy(isLoading: true, error: null, days: {}));
    try {
      final methods = await _source.loadPaymentMethods();
      if (_disposed || request != _request) return;
      final selected = methods
          .where(
            (method) => method.isCredit && method.id == snapshot.selectedCardId,
          )
          .firstOrNull;
      // A removed card falls back to All. Updated closing days take effect here.
      final window = CalendarWindow.containing(
        _state.selectedDate,
        closingDay: selected?.closingDay,
      );
      final results = await Future.wait<Object>([
        _source.loadTransactions(
          ledgerId: ledgerId,
          window: window,
          paymentMethodId: selected?.id,
        ),
        _source.loadIncome(ledgerId: ledgerId, window: window),
        _source.loadNotes(ledgerId: ledgerId, window: window),
      ]);
      if (_disposed || request != _request) return;
      final days = buildCalendarDays(
        ledgerId: ledgerId,
        window: window,
        selectedCardId: selected?.id,
        paymentMethods: methods,
        transactions: results[0] as List<CalendarTransaction>,
        income: results[1] as List<CalendarIncome>,
        notes: results[2] as List<CalendarNote>,
      );
      _emit(
        _state._copy(
          window: window,
          selectedCardId: selected?.id,
          selectedDate: window.contains(_state.selectedDate)
              ? _state.selectedDate
              : window.start,
          paymentMethods: methods,
          days: days,
          isLoading: false,
          error: null,
        ),
      );
    } catch (error) {
      if (!_disposed && request == _request) {
        _emit(_state._copy(isLoading: false, error: error, days: {}));
      }
    }
  }

  /// Hook for the dropdown; null selects All. Cash has no billing cycle option.
  Future<void> selectCard(String? id) {
    _checkActive();
    if (id != null && !_state.cards.any((method) => method.id == id)) {
      throw ArgumentError.value(id, 'id', 'Choose a registered credit card');
    }
    if (id == _state.selectedCardId) return Future.value();
    final card = _state.cards.where((method) => method.id == id).firstOrNull;
    _emit(
      _state._copy(
        selectedCardId: id,
        window: CalendarWindow.containing(
          _state.selectedDate,
          closingDay: card?.closingDay,
        ),
        days: {},
      ),
    );
    return refresh();
  }

  Future<void> previousPeriod() => _move(-1);
  Future<void> nextPeriod() => _move(1);

  Future<void> _move(int amount) {
    _checkActive();
    final window = _state.window.shifted(amount, closingDay: _closingDay);
    final today = calendarDate(_clock());
    _emit(
      _state._copy(
        window: window,
        selectedDate: window.contains(today) ? today : window.start,
        days: {},
      ),
    );
    return refresh();
  }

  /// Date-picker hook: opens the month or card cycle containing the given date.
  Future<void> jumpToDate(DateTime date) {
    _checkActive();
    final day = calendarDate(date);
    if (_state.window.contains(day)) {
      selectDate(day);
      return Future.value();
    }
    _emit(
      _state._copy(
        window: CalendarWindow.containing(day, closingDay: _closingDay),
        selectedDate: day,
        days: {},
      ),
    );
    return refresh();
  }

  Future<void> goToToday() => jumpToDate(_clock());

  /// Day-cell hook. Reads already-loaded data; never sends a request.
  void selectDate(DateTime date) {
    _checkActive();
    if (!_state.window.contains(date)) {
      throw ArgumentError(
        'Use jumpToDate to select outside the current window',
      );
    }
    _emit(_state._copy(selectedDate: calendarDate(date)));
  }

  /// Save/clear the selected day's note. Returns false on failure so a future
  /// editor can preserve its draft. Duplicate saves are blocked while pending.
  Future<bool> saveSelectedNote(String content) async {
    _checkActive();
    if (_state.isSavingNote) throw StateError('A note save is already pending');
    final date = _state.selectedDate;
    _emit(_state._copy(isSavingNote: true, noteError: null));
    try {
      await _source.saveNote(ledgerId: ledgerId, date: date, content: content);
      if (_disposed) return true;
      _emit(_state._copy(isSavingNote: false, noteError: null));
      // Reload the current window, even if navigation happened during the save.
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
