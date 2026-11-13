# Spending Tracker

Spending Tracker is a mobile spending tracker with a Flutter app for iOS and Android and a FastAPI backend.

## Tech Specs

* backend: Python + FastAPI + SQLAlchemy (Supabase PostgreSQL and Auth)
* frontend: Flutter (iOS and Android)

## Main Features (Upcoming)

* Track your spending based on types of your spending(credit, debit, cash, etc)
* Set the calendar that fits best for your spending methods
* Look at your spending dashboard with various visualization
* Parse your receipts to automatically record your detailed spendings
* Wait for more features on Pro mode!!

## Project Architecture

```text
spendTracker/
├── frontend/            # Flutter iOS and Android app
├── backend/             # FastAPI app
└── Spending-tracker.md  # Project plan
```

## Prerequisites

* Flutter 3.47
* Python 3.12
* uv

## Installation

### Frontend
```bash
cd frontend
flutter pub get
```

### Backend
```bash
cd backend
uv sync
```

## Environment Variables

Copy the backend environment example locally:

```bash
cp backend/.env.example backend/.env
```

## How to Run

### Backend
```bash
cd backend
uv run fastapi dev app/main.py
```

Protected backend routes require `SUPABASE_URL` in `backend/.env`. `SUPABASE_JWKS_URL` is optional; it defaults to the project's Auth JWKS endpoint. JWT verification via JWKS requires asymmetric Supabase signing keys.

For routes under `/ledgers/{ledger_id}/...`, depend on `get_user_ledger` from `app.ledgers.dependencies`. It verifies the Bearer token, checks `ledger_members`, and returns 404 for a missing or inaccessible ledger. Ledger creation must add the owner to `ledger_members`. Feature repositories must still filter their own queries by `ledger_id`.

### Frontend
```bash
cd frontend
flutter run
```

## Calendar API

`GET /ledgers/{ledger_id}/calendar?anchor_date=2026-11-06` returns the ordinary
month. Add `payment_method_id=<credit-card UUID>` to resolve that card's billing
cycle and limit transactions to that card. The card must belong to the caller;
invalid, foreign and cash-like selections return 404. Ledger membership and
active-account checks apply as on other ledger routes. Anchor years 2–9997 are
supported, leaving space for adjacent periods and holiday years.

The response contains `mode`, `payment_method_id`, inclusive `start_date` and
`end_date`, `previous_anchor_date`, `next_anchor_date`, `payment_methods`, `cards`, and
ordered `days` including empty dates. Each day includes full `transactions` and
their `items`, `dots` with payment-method colors/counts, planned/received `income`,
`closing_cards`, `note`, `spending_cents`, and `received_income_cents`. All mode
includes Paycheck, Cashback and Other income. Card mode includes only planned or
received Cashback linked to that card; received-income totals follow the same
filter. All mode shows every wallet card's closing event; card mode shows only
the selected card's closing event. Notes remain visible in either mode.
Stored transaction totals already include tax/tip; planned income does not count
as received money. A closing day of 12 yields the 13th through the following 12th;
days 29–31 clamp to the month's actual last date.

The read model uses parameterized raw PostgreSQL queries, including CTEs and
aggregates, through the authorized request's SQLAlchemy connection. Existing CRUD/range endpoints remain
available. Holiday caching preserves the existing income API policy: cached or
stale holidays are used where available; without a calendar, the expected payday
is returned unadjusted. Only refreshed holiday caches are written by this GET.

To verify in `/docs`, authorize with an existing access token, expand the calendar
GET, supply your ledger UUID and anchor date, and optionally a card UUID. Use its
returned navigation anchors for adjacent windows. Notes still use the existing
day-note PUT, followed by a reload.

### Calendar PostgreSQL tests

From `backend/`, set `CALENDAR_TEST_DB_URL` to a PostgreSQL test connection and run
`uv run pytest tests/test_calendar_postgres.py`. Alternatively, explicitly opt in
to the configured local `DB_URL` with
`CALENDAR_TEST_USE_CONFIGURED_DB=1 uv run pytest tests/test_calendar_postgres.py`.
Tests create/reuse permanent `test1` and `test1_auth` schemas and retain their
fixture data afterward for inspection in Supabase's Table Editor. Each test has
a reusable dataset: one indexed lookup skips existing base fixtures, and stable
IDs with `ON CONFLICT DO NOTHING` prevent duplicate scenario records on reruns.
The shared test holiday cache is reset before each test; financial records are
retained. Earlier random datasets remain untouched; each test seeds its reusable
version once. Increment the fixture version when changing scenario data.
`test1.calendar_test_cases` maps test names to their user, ledger and card UUIDs.
The fixture definitions in `backend/tests/test_calendar_postgres.py` recreate the
sample data for teammates; no database contents or credentials need to be copied.
The connection needs create-schema permission; existing app/auth tables outside
these test schemas are not modified. Run this suite sequentially because its
holiday cache is shared. Tests skip without either opt-in. CI supplies a
disposable PostgreSQL service and runs these tests too.

For the optional real Dart HTTP smoke test, also set `CALENDAR_TEST_DART` to the
installed `dart` executable. It runs the frontend adapter against a temporary
FastAPI test server and the isolated PostgreSQL fixtures, covering full item
detail, card navigation and note save/clear. Authentication is overridden only
inside that test; no real Auth session is required or tested.

## Profile and account deletion

Authenticated users can read their app profile with `GET /users/me` and update the display name with `PATCH /users/me` and a JSON body such as `{"nickname": "Mellow Otter"}`. Email and login credentials remain in Supabase Auth.

`DELETE /users/me` permanently removes the user's personal app data and then requests deletion of the Supabase Auth user. Configure the server-only `SUPABASE_SECRET_KEY` in `backend/.env`; it must not be included in Flutter, logs, or Git. A completed request returns 204. If the Auth API is unavailable, the API returns 503 and keeps a deletion request pending; regular app access is blocked while deletion is pending, and the same endpoint can be retried.

Operators can retry pending requests from `backend/` with `uv run python -m app.users.retry_deletions`. This command is not scheduled automatically. Set up and monitor a deployment job before relying on unattended retries. Shared-ledger ownership and removal are not yet supported; deletion of an owned ledger with other members is blocked by database constraints and rolled back.

## References

For product details, see [Spending-tracker.md](./Spending-tracker.md).

For AI-assisted Flutter work, see the [GJC frontend workflow](./docs/gjc-frontend-workflow.md).
