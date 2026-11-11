// Optional cross-stack test, launched by the PostgreSQL pytest fixture server.
// Uses isolated fixtures and a test authentication override, not a real session.
import 'dart:io';

import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar.dart';

Future<void> main() async {
  final env = Platform.environment;
  final api = ApiClient(
    baseUrl: Uri.parse(env['CALENDAR_SMOKE_URL']!),
    accessToken: () => 'calendar-integration-test',
  );
  final controller = CalendarController(
    ledgerId: env['CALENDAR_SMOKE_LEDGER']!,
    dataSource: HttpCalendarDataSource(api),
    clock: () => DateTime(2026, 11, 6),
  );
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  try {
    await controller.refresh();
    check(controller.state.error == null, 'Initial calendar load failed');
    check(controller.state.days.length == 30, 'Incomplete month');
    final day = controller.state.selectedDay!;
    check(
      day.transactions.single.items.single.name == 'Item 0',
      'Missing transaction detail',
    );
    check(day.spendingCents == 130, 'Incorrect server total');
    await controller.selectCard(env['CALENDAR_SMOKE_CARD']!);
    check(controller.state.error == null, 'Card load failed');
    check(
      controller.state.window!.start == DateTime.utc(2026, 10, 13),
      'Wrong card cycle',
    );
    check(
      await controller.saveSelectedNote('Integration note'),
      'Note save failed',
    );
    check(
      controller.state.selectedDay!.note!.content == 'Integration note',
      'Note missing on reload',
    );
    check(await controller.saveSelectedNote(''), 'Note clear failed');
    check(controller.state.selectedDay!.note == null, 'Note not cleared');
    await controller.nextPeriod();
    check(
      controller.state.window!.start == DateTime.utc(2026, 11, 13),
      'Wrong next cycle',
    );
    await controller.previousPeriod();
    check(
      controller.state.selectedDate == DateTime.utc(2026, 11, 6),
      'Today not selected on return',
    );
    stdout.writeln('Dart HTTP -> FastAPI -> PostgreSQL calendar smoke passed');
  } finally {
    controller.dispose();
    api.close();
  }
}
