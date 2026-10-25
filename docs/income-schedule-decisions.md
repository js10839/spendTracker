# Income schedule: open decision

## Current behavior

- `income_sources.next_expected_date` stores the next unconfirmed planned deposit date. `income_records` stores money actually received.
- Biweekly schedules advance by 14 days. Monthly schedules keep the original day of month where possible.
- The current calculation does not move a planned deposit date for weekends or holidays.

## Decide after deposit confirmation is complete

- Whether an expected deposit on a weekend or holiday should move, and in which direction. This may depend on the payer or deposit method; do not assume every deposit arrives on the preceding Friday.
- Which country's or region's holiday calendar applies, and whether the user can set a schedule-specific adjustment rule.
- Keep this scheduling rule in `income/`, which owns planned deposits. `cycles/` owns card statement periods, not income dates.

Until these rules are agreed, show the saved expected date without automatic holiday or weekend adjustment.
