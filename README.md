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
* Access to the team's Supabase project (PostgreSQL and Auth)

## Backend setup

Run these commands from the repository root:

```bash
cp backend/.env.example backend/.env
cd backend
uv sync --locked --dev
```

Set `DB_URL`, `SUPABASE_URL`, and `BANKDAY_KEY` in `backend/.env` using values shared by the team through a private channel. `DB_URL` is the PostgreSQL connection used by SQLAlchemy and Alembic. `SUPABASE_URL` identifies the Auth project whose access tokens the API accepts. `SUPABASE_JWKS_URL` is optional; it defaults to that project's JWKS endpoint. `BANKDAY_KEY` retrieves annual US Federal Reserve bank holidays for Paycheck display dates; the backend shares a database cache and refreshes current or future years on the first read after 30 days. Without a cached calendar or a working key, `adjusted_expected_date` is null. JWT verification requires asymmetric Supabase signing keys. Do not commit credentials or `.env` files.

Apply migrations to a **new or personal database** before using the API:

```bash
uv run alembic upgrade head
```

If the team shares one database, agree on one person to apply each migration. Other developers can check its revision with `uv run alembic current` and compare it with `uv run alembic heads`.

Start the backend from `backend/`:

```bash
uv run fastapi dev app/main.py
```

Check that it responds at `http://127.0.0.1:8000/health/live`. Interactive API documentation is available at `http://127.0.0.1:8000/docs`.

## First authenticated request

Sign in with a test account through Supabase Auth and use its **access token** as the Bearer token. Create a test account in the team's Auth project if needed; never put its password or access token in the repository. From a separate terminal, set `ACCESS_TOKEN` locally, then initialize the app profile:

```bash
curl -X POST http://127.0.0.1:8000/users/me/bootstrap \
  -H "Authorization: Bearer $ACCESS_TOKEN"
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

The read model uses SQLAlchemy Core tables, CTEs and PostgreSQL aggregates through
the authorized request's connection. Existing CRUD/range endpoints remain
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
Tests create unique temporary app/auth schemas, use rollback-isolated fixtures,
and remove the schemas afterward. The connection needs create-schema permission;
existing app/auth tables and records are not modified. Tests skip without either
opt-in. CI supplies a disposable PostgreSQL service and runs these tests too.

For the optional real Dart HTTP smoke test, also set `CALENDAR_TEST_DART` to the
installed `dart` executable. It runs the frontend adapter against a temporary
FastAPI test server and the isolated PostgreSQL fixtures, covering full item
detail, card navigation and note save/clear. Authentication is overridden only
inside that test; no real Auth session is required or tested.
Bootstrap creates `public.users`, a Personal ledger andㅌ its owner membership, and the default Cash payment method. It uses the UUID from the Auth token, so repeat calls for the same account reuse its profile. Its response includes `user_id` and `onboarding_required`. After OTP verification, an account requiring signup information can complete it with `POST /users/me/onboarding/complete` and a JSON body such as `{"nickname": "Mellow Otter"}`. An empty nickname is generated by the server; repeated completion requests retain the existing name. The Flutter signup flow does not yet consume these fields or call the completion endpoint.

Find the ledger ID and wallet with:

```bash
curl http://127.0.0.1:8000/ledgers -H "Authorization: Bearer $ACCESS_TOKEN"
curl http://127.0.0.1:8000/users/me/payment-methods -H "Authorization: Bearer $ACCESS_TOKEN"
curl http://127.0.0.1:8000/categories -H "Authorization: Bearer $ACCESS_TOKEN"
```

Expense and income APIs live under `/ledgers/{ledger_id}/...`; wallet APIs live under `/users/me/payment-methods`. For ledger routes, `get_user_ledger` verifies the token and membership and returns 404 for an inaccessible ledger. Feature repositories must also filter data by `ledger_id`.

## Profile and account deletion

Authenticated users can read their app profile with `GET /users/me` and update the display name with `PATCH /users/me` and a JSON body such as `{"nickname": "Mellow Otter"}`. Email and login credentials remain in Supabase Auth.

`DELETE /users/me` permanently removes the user's personal app data and then requests deletion of the Supabase Auth user. Configure the server-only `SUPABASE_SECRET_KEY` in `backend/.env`; it must not be included in Flutter, logs, or Git. A completed request returns 204. If the Auth API is unavailable, the API returns 503 and keeps a deletion request pending; regular app access is blocked while deletion is pending, and the same endpoint can be retried.

Operators can retry pending requests from `backend/` with `uv run python -m app.users.retry_deletions`. This command is not scheduled automatically. Set up and monitor a deployment job before relying on unattended retries. Shared-ledger ownership and removal are not yet supported; deletion of an owned ledger with other members is blocked by database constraints and rolled back.

## Receipt parsing API

`POST /receipts/parse` accepts a `multipart/form-data` image in the `file` field
and does not require a login or access token. Set
`OPENAI_API_KEY` in `backend/.env`; optionally set `OPENAI_RECEIPT_MODEL`.
Supported formats are JPEG, PNG, WEBP, and MPO, up to 10 MiB and 32 million pixels.

```bash
curl http://127.0.0.1:8000/receipts/parse \
  -F "file=@/path/to/receipt.jpg"
```

The response contains `receipt` (merchant, location, date, currency, items, tax,
tip, total) and `validation` (status, calculated_total, receipt_total, difference,
item_count, issues). Monetary amounts are JSON strings. A `review` status is a
successful parse requiring user review, such as when totals differ. This endpoint
uses the fixed categories in `app/receipts/schemas.py` and does not save a transaction
or receipt image. The DB-driven schema in `schemas_DB.py` is not used here.

Errors: 413 for oversized files; 422 for missing, empty, invalid, or unsupported
images; 502 for parsing provider/output failures; 503 if the API key is missing;
504 for provider timeouts. Try the upload directly through `/docs`.

## Frontend setup

```bash
cd frontend
flutter pub get
flutter run
```

The Flutter app may call Supabase directly for Auth. Application data goes through FastAPI.

## Checks

Run these from `backend/`:

```bash
uv run ruff check .
uv run pytest
```

## References

For product details, see [Spending-tracker.md](./Spending-tracker.md).

For AI-assisted Flutter work, see the [GJC frontend workflow](./docs/gjc-frontend-workflow.md).
