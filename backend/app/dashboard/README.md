# Dashboard backend

`GET /ledgers/{ledger_id}/dashboard` requires the existing Bearer authentication
and ledger membership. It returns one JSON response with all dashboard sections.
No frontend changes or production migrations are required.

## Query parameters

| Parameter | Meaning |
| --- | --- |
| `as_of` (required date) | User's local today, e.g. `2026-11-13`. All spending excludes dates after this date. |
| `month` (optional date) | Month to chart; any date in that month. Defaults to `as_of` month. |
| `year` (optional integer) | Year to chart; defaults to `as_of` year. |
| `payment_method_id` (optional UUID) | Owned credit card for monthly/yearly charts and category breakdown; omit for All. |
| `category_start`, `category_end` (optional dates) | Both or neither; inclusive category window, at most 366 days. Defaults to selected month. |

Example: `/ledgers/{id}/dashboard?as_of=2026-11-13&month=2026-10-01&year=2026`.
All dates must have years between 2 and 9997. Currency is USD; 422 is returned if
relevant transactions use another currency. Other currencies need a conversion or
separate-currency product decision before they can be summed.

## Response sections and rules

- `spending_30_days`: ledger-wide sum, `as_of - 29` through `as_of`, inclusive.
- `card_statements`: every credit card owned by the current user, including empty
  cards. Amount is **spending recorded so far**, not a forecast, card balance, or
  amount owed after repayments/cashback. Bounds include the full current cycle;
  `spent_through` is `as_of`. Closing day clamps to the last day of short months;
  the next cycle starts the following day, matching the calendar.
- `top_categories`: up to three item categories for each card's current cycle,
  ranked by signed net item amount descending, ties by name then ID. Tax/tip and
  unitemized remainder are excluded from this ranking.
- `next_payday`: earliest upcoming planned **paycheck**, including today. Amount
  sums sources paying on that date; `sources` preserves each amount and original
  expected date. Returns null when there are no upcoming paycheck plans. Overdue
  unconfirmed occurrences are skipped; monthly/biweekly recurrence is advanced in
  SQL without updating the plan. Monthly dates retain the original anchor day.
  Uses the existing bank-holiday cache refresh and preceding-business-day rules;
  stale cache is usable, absent cache falls back to the original expected date.
  Cashback and Other income never count as payday.
- `monthly_spending`: daily buckets for the selected calendar month.
- `yearly_spending`: twelve buckets, dated on each month's first day.
  Both include zeros; future buckets are zero. Card selection applies to both.
- `cycle_pace`: All plus every owned credit card. All uses calendar months; cards
  use billing cycles. Each compares current spending through `as_of` with the same
  number of elapsed days in the previous period, capped at that period's end.
  Returned comparison bounds make unequal period lengths explicit. These are
  partial-period totals, not full previous statements. Never subtract cashback.
- `category_breakdown`: selected range/card, grouped by item category. A null-ID
  `Tax, tip & unitemized` remainder reconciles categories with transaction totals;
  it is omitted when zero. Includes category names, not frontend color choices.

Deleted transactions and inactive/deleted income plans are excluded. All sums are
integer cents, and transaction totals are summed once regardless of item count.
Refunds retain their signed amounts. Category amounts can therefore be zero or
negative: the UI must account for that when drawing a pie (a negative value cannot
be represented as an ordinary positive slice). No absolute-value conversion or
silent removal changes the accounting totals.

## Implementation and verification

`router.py` handles request/dependency wiring, `service.py` validates inputs and
manages the holiday-cache transaction, and `repository.py` contains bound raw
PostgreSQL statements. SQL performs selection, periods, aggregation, category
ranking, zero filling, recurrence, and JSON construction. Dashboard-owned period
SQL and holiday helpers follow calendar behavior without importing its repository
or service, so this feature can merge independently of the calendar SQL refactor.

Tests live here to keep the feature within this folder. The pytest testpaths entry
includes them in the normal backend test run and CI. Run just this feature with:

```sh
cd backend
uv run pytest app/dashboard/tests -q --tb=short
```

Live PostgreSQL tests are opt-in; see their module for reusable `test2` fixture
details. They never seed the production schema or delete the retained samples.
Set `DASHBOARD_TEST_USE_CONFIGURED_DB=1` to use the local configured database, or
provide `DASHBOARD_TEST_DB_URL`. CI's existing `CALENDAR_TEST_DB_URL` is also
accepted and points to its disposable PostgreSQL service, never Supabase.

The reusable samples are defined in tests/conftest.py and test_postgres.py, so
they are reviewable in the PR and reproducible on another database. A primary-key
lookup in test2.dashboard_test_cases skips existing base fixtures; deterministic
UUIDs and conflict-safe inserts reuse the scenario rows. Run tests sequentially.
To change a retained scenario, increment its fixture version/UUID namespace rather
than expecting existing sample values to be overwritten.

Verified: 40 dashboard tests pass, including 17 against PostgreSQL. A repeated run
left exact row counts unchanged across all 13 test2/test2_auth tables. The existing
non-live backend suite plus dashboard API/service tests passes (192 tests).
