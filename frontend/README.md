# Spending Tracker Flutter App

This directory is the iOS and Android Flutter app. The previous React/Vite scaffold has been replaced. Product behavior and screen requirements are defined in [Spending-tracker.md](../Spending-tracker.md).

## Run locally

Install Flutter, then run from this directory:

```bash
flutter pub get
flutter run
```

For the current scaffold, verify changes with:

```bash
flutter analyze
flutter test
```

`lib/main.dart` currently contains only a minimal launch screen. Calendar logic and its FastAPI request adapter are available, but feature screens and Supabase Auth/session handling have not been added yet. App data must go through FastAPI; the mobile app may call Supabase directly only for Auth.

## Calendar requests

`ApiClient` sends JSON requests using a token supplied by the caller.
`HttpCalendarDataSource` implements the calendar's existing data-source interface
for payment methods, date-range transactions, income, notes, and note saving.
Selecting a card sends its `payment_method_id` only on transaction requests.

Construct the controller with an existing access token and ledger ID:

```dart
import 'package:spending_tracker/api/api_client.dart';
import 'package:spending_tracker/calendar/calendar.dart';

final api = ApiClient(
  baseUrl: Uri.parse(backendUrl),
  accessToken: () => existingAccessToken,
);
final calendar = CalendarController(
  ledgerId: existingLedgerId,
  dataSource: HttpCalendarDataSource(api),
);
await calendar.refresh();
// Observe calendar.changes, with calendar.state as the initial snapshot.
// Later, on teardown:
calendar.dispose();
api.close();
```

The base URL is the FastAPI server, not the Supabase URL. A caller can supply
configuration through `String.fromEnvironment('API_BASE_URL')` or another app
configuration mechanism. Android emulators typically reach the development
machine through `http://10.0.2.2:8000`; a device needs a reachable host URL.
Use HTTPS for deployed backends. Local HTTP access may need platform-specific
development configuration, and browser access needs matching backend CORS setup.

The token callback is read on every request. It may return a token asynchronously,
but this code does not log in, persist tokens, refresh tokens, or retry 401s.
Supply a user access token, not a Supabase API key. Missing tokens fail before
sending a request. Backend failures expose `ApiException.statusCode` and `detail`;
transport errors, timeouts, and invalid JSON also propagate to calendar state.
Callers retain ownership of an explicitly injected `http.Client` and must close it.

Run the request and calendar tests without a server or credentials:

```bash
flutter test test/api_client_test.dart test/http_calendar_data_source_test.dart test/calendar_dates_test.dart test/calendar_projection_test.dart test/calendar_controller_test.dart
```

Before a store release, replace the generated `com.example` Android application ID and iOS bundle identifier with the team's chosen identifiers.
