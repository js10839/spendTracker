# Income schedule: agreed MVP rule

## Current behavior

- `income_sources.next_expected_date` stores the next unconfirmed planned deposit date. `income_records` stores money actually received.
- Biweekly schedules advance by 14 days. Monthly schedules keep the original day of month where possible.
- Paycheck plans keep `next_expected_date` as the recurrence anchor and return `adjusted_expected_date` for display. Weekends and US Federal Reserve bank holidays move the display date to the preceding business day.
- Bankday supplies the `us-fed` annual holiday list. The backend caches each year in `bank_calendar_years`; current and future years refresh on the first read after 30 days. A cached list remains usable if Bankday is unavailable. Without a cached list, the adjusted date is null.

## Still open

- Whether payers need schedule-specific adjustment rules; the MVP uses the preceding US bank business day as an estimate, not a guarantee of actual deposit timing.
- Whether users outside the US need another calendar or a selectable region.
- Keep this scheduling rule in `income/`, which owns planned deposits. `cycles/` owns card statement periods, not income dates.

There is no background scheduler yet. Cache refresh happens when a Paycheck plan is read.
