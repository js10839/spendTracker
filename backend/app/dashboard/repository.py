"""Dashboard selection and aggregation in parameterized PostgreSQL."""

from datetime import date
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.engine import Connection

from app.calendar.repository import PERIOD_SQL


def _period(anchor: str, closing: str) -> str:
    """Compose only trusted SQL expressions; user inputs remain bound parameters."""
    return PERIOD_SQL.replace(":anchor_date", anchor).replace(":closing_day", closing)


DASHBOARD_SQL = (
    """
WITH params AS (
    SELECT CAST(:ledger_id AS uuid) AS ledger_id, CAST(:user_id AS uuid) AS user_id,
           CAST(:as_of AS date) AS as_of,
           date_trunc('month', CAST(:month AS date))::date AS month_start,
           make_date(:year, 1, 1) AS year_start,
           COALESCE(CAST(:category_start AS date),
               date_trunc('month', CAST(:month AS date))::date) AS category_start,
           COALESCE(CAST(:category_end AS date),
               (date_trunc('month', CAST(:month AS date)) + INTERVAL '1 month')::date - 1) AS category_end,
           CAST(:payment_method_id AS uuid) AS selected_card
),
wallet AS (
    SELECT m.id, m.name, m.color, m.closing_day FROM payment_methods m, params p
    WHERE m.user_id = p.user_id AND m.type = 'credit'
),
modes AS (
    SELECT id, name, color, closing_day FROM wallet
    UNION ALL SELECT NULL::uuid, 'All', NULL::text, NULL::integer
),
periods AS (
    SELECT m.*, cur.start_date, cur.end_date,
           prev.start_date AS previous_start, prev.end_date AS previous_end,
           p.as_of - cur.start_date + 1 AS elapsed_days,
           LEAST(prev.end_date, prev.start_date + (p.as_of - cur.start_date))
               AS previous_through
    FROM modes m CROSS JOIN params p
    CROSS JOIN LATERAL (
"""
    + _period("p.as_of", "m.closing_day")
    + """
    ) cur
    CROSS JOIN LATERAL (
"""
    + _period("cur.start_date - 1", "m.closing_day")
    + """
    ) prev
),
windows AS (
    SELECT 'current' AS kind, id AS method_id, start_date, p.as_of AS end_date
    FROM periods CROSS JOIN params p
    UNION ALL
    SELECT 'previous', id, previous_start, previous_through FROM periods
    UNION ALL SELECT 'rolling', NULL, as_of - 29, as_of FROM params
    UNION ALL SELECT 'month', selected_card, month_start,
        (month_start + INTERVAL '1 month')::date - 1 FROM params
    UNION ALL SELECT 'year', selected_card, year_start,
        (year_start + INTERVAL '1 year')::date - 1 FROM params
    UNION ALL SELECT 'category', selected_card, category_start, category_end FROM params
),
spending AS MATERIALIZED (
    SELECT t.* FROM transactions t CROSS JOIN params p
    WHERE t.ledger_id = p.ledger_id AND t.deleted_at IS NULL
      AND t.transacted_at <= p.as_of
      AND t.transacted_at >= (SELECT min(start_date) FROM windows)
      AND t.transacted_at <= (SELECT max(end_date) FROM windows)
      AND EXISTS (SELECT 1 FROM windows w
          WHERE t.transacted_at BETWEEN w.start_date AND w.end_date
            AND (w.method_id IS NULL OR t.payment_method_id = w.method_id))
),
totals AS (
    SELECT w.kind, w.method_id, COALESCE(sum(t.total_cents), 0)::bigint AS amount
    FROM windows w LEFT JOIN spending t
      ON t.transacted_at BETWEEN w.start_date AND w.end_date
     AND (w.method_id IS NULL OR t.payment_method_id = w.method_id)
    GROUP BY w.kind, w.method_id
),
category_sums AS (
    SELECT w.kind, w.method_id, i.category_id, c.name,
           sum(i.amount_cents)::bigint AS amount_cents
    FROM windows w JOIN spending t
      ON t.transacted_at BETWEEN w.start_date AND w.end_date
     AND (w.method_id IS NULL OR t.payment_method_id = w.method_id)
    JOIN transaction_items i ON i.transaction_id = t.id
    JOIN categories c ON c.id = i.category_id
    WHERE w.kind IN ('current', 'category')
    GROUP BY w.kind, w.method_id, i.category_id, c.name
),
ranked_categories AS (
    SELECT *, row_number() OVER (PARTITION BY method_id
        ORDER BY amount_cents DESC, name, category_id) AS rank
    FROM category_sums WHERE kind = 'current' AND method_id IS NOT NULL
),
pie_categories AS (
    SELECT category_id, name, amount_cents FROM category_sums WHERE kind = 'category'
    UNION ALL
    SELECT NULL::uuid, 'Tax, tip & unitemized',
        (SELECT amount FROM totals WHERE kind = 'category') -
        COALESCE((SELECT sum(amount_cents) FROM category_sums WHERE kind = 'category'), 0)
),
days AS (
    SELECT d.day::date AS date, COALESCE(sum(t.total_cents), 0)::bigint AS total_cents
    FROM params p CROSS JOIN generate_series(p.month_start::timestamp,
        p.month_start::timestamp + INTERVAL '1 month - 1 day', INTERVAL '1 day') d(day)
    LEFT JOIN spending t ON t.transacted_at = d.day::date
        AND (p.selected_card IS NULL OR t.payment_method_id = p.selected_card)
    GROUP BY d.day
),
months AS (
    SELECT d.day::date AS date, COALESCE(sum(t.total_cents), 0)::bigint AS total_cents
    FROM params p CROSS JOIN generate_series(p.year_start::timestamp,
        p.year_start::timestamp + INTERVAL '11 months', INTERVAL '1 month') d(day)
    LEFT JOIN spending t ON t.transacted_at >= d.day::date
        AND t.transacted_at < (d.day + INTERVAL '1 month')::date
        AND (p.selected_card IS NULL OR t.payment_method_id = p.selected_card)
    GROUP BY d.day
),
statements AS (
    SELECT r.id AS payment_method_id, r.name, r.color, r.start_date, r.end_date,
           p.as_of AS spent_through, t.amount AS total_cents,
           COALESCE((SELECT jsonb_agg(jsonb_build_object(
               'category_id', c.category_id, 'name', c.name, 'amount_cents', c.amount_cents)
               ORDER BY c.rank) FROM ranked_categories c
               WHERE c.method_id = r.id AND c.rank <= 3), '[]'::jsonb) AS top_categories
    FROM periods r CROSS JOIN params p
    JOIN totals t ON t.kind = 'current' AND t.method_id = r.id
    WHERE r.id IS NOT NULL
),
pace AS (
    SELECT CASE WHEN r.id IS NULL THEN 'all' ELSE 'card' END AS mode,
           r.id AS payment_method_id, r.name, r.color, r.elapsed_days,
           r.previous_through - r.previous_start + 1 AS previous_elapsed_days,
           jsonb_build_object('start_date', r.start_date, 'end_date', p.as_of,
               'total_cents', c.amount) AS current,
           jsonb_build_object('start_date', r.previous_start,
               'end_date', r.previous_through, 'total_cents', prev.amount) AS previous,
           r.end_date AS current_cycle_end, r.previous_end AS previous_cycle_end
    FROM periods r CROSS JOIN params p
    JOIN totals c ON c.kind = 'current' AND c.method_id IS NOT DISTINCT FROM r.id
    JOIN totals prev ON prev.kind = 'previous' AND prev.method_id IS NOT DISTINCT FROM r.id
)
SELECT EXISTS(SELECT 1 FROM spending WHERE currency <> 'USD') AS unsupported_currency,
       jsonb_build_object('start_date', p.as_of - 29, 'end_date', p.as_of,
           'total_cents', (SELECT amount FROM totals WHERE kind = 'rolling')) AS spending_30_days,
       (SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.name, s.payment_method_id),
            '[]'::jsonb) FROM statements s) AS card_statements,
       jsonb_build_object('start_date', p.month_start,
           'end_date', (p.month_start + INTERVAL '1 month')::date - 1,
           'buckets', (SELECT jsonb_agg(to_jsonb(d) ORDER BY d.date) FROM days d)) AS monthly_spending,
       jsonb_build_object('start_date', p.year_start,
           'end_date', (p.year_start + INTERVAL '1 year')::date - 1,
           'buckets', (SELECT jsonb_agg(to_jsonb(m) ORDER BY m.date) FROM months m)) AS yearly_spending,
       (SELECT jsonb_agg(to_jsonb(c) ORDER BY c.payment_method_id NULLS FIRST) FROM pace c) AS cycle_pace,
       jsonb_build_object('start_date', p.category_start, 'end_date', p.category_end,
           'total_cents', (SELECT amount FROM totals WHERE kind = 'category'),
           'categories', (SELECT COALESCE(jsonb_agg(to_jsonb(c)
               ORDER BY c.amount_cents DESC, c.name, c.category_id), '[]'::jsonb)
               FROM pie_categories c WHERE c.amount_cents <> 0)) AS category_breakdown
FROM params p
"""
)

# A bounded set around today's recurrence index avoids walking historical days.
PAYDAY_SQL = """
WITH RECURSIVE params AS (
    SELECT CAST(:ledger_id AS uuid) AS ledger_id, CAST(:as_of AS date) AS as_of
), sources AS (
    SELECT s.*, p.as_of,
        GREATEST(0, ceil((p.as_of - s.next_expected_date)::numeric / 14))::integer AS biweek,
        GREATEST(1, (EXTRACT(year FROM p.as_of)::integer -
            EXTRACT(year FROM s.next_expected_date)::integer) * 12 +
            EXTRACT(month FROM p.as_of)::integer -
            EXTRACT(month FROM s.next_expected_date)::integer) AS month_offset
    FROM income_sources s CROSS JOIN params p
    WHERE s.ledger_id = p.ledger_id AND s.is_active IS TRUE
      AND s.deleted_at IS NULL AND s.income_type = 'paycheck'
), candidates AS (
    SELECT s.id, s.from_name, s.expected_amount_cents AS amount_cents,
           s.next_expected_date AS expected_date FROM sources s
    UNION
    SELECT s.id, s.from_name, s.expected_amount_cents,
           s.next_expected_date + ((s.biweek + n) * 14)
    FROM sources s CROSS JOIN generate_series(0, 2) n WHERE s.frequency = 'biweekly'
    UNION
    SELECT s.id, s.from_name, s.expected_amount_cents,
           m.month + LEAST(EXTRACT(day FROM s.reference_date)::integer,
               EXTRACT(day FROM m.month + INTERVAL '1 month - 1 day')::integer) - 1
    FROM sources s CROSS JOIN generate_series(0, 2) n
    CROSS JOIN LATERAL (SELECT (date_trunc('month', s.next_expected_date) +
        make_interval(months => s.month_offset + n))::date AS month) m
    WHERE s.frequency = 'monthly'
), walk AS (
    SELECT c.*, c.expected_date AS display_date FROM candidates c
    UNION ALL
    SELECT w.id, w.from_name, w.amount_cents, w.expected_date, w.display_date - 1
    FROM walk w JOIN bank_calendar_years b ON b.year = EXTRACT(year FROM w.display_date)
    WHERE EXTRACT(isodow FROM w.display_date) > 5
       OR b.holidays::jsonb @> jsonb_build_array(w.display_date::text)
), resolved AS (
    SELECT w.*, CASE WHEN b.year IS NULL THEN w.expected_date ELSE w.display_date END AS payday
    FROM walk w LEFT JOIN bank_calendar_years b ON b.year = EXTRACT(year FROM w.display_date)
    WHERE b.year IS NULL OR (EXTRACT(isodow FROM w.display_date) <= 5
        AND NOT (b.holidays::jsonb @> jsonb_build_array(w.display_date::text)))
), upcoming AS (
    SELECT r.* FROM resolved r, params p WHERE r.payday >= p.as_of
), next_day AS (
    SELECT * FROM upcoming WHERE payday = (SELECT min(payday) FROM upcoming)
)
SELECT CASE WHEN count(*) = 0 THEN NULL ELSE jsonb_build_object(
    'date', min(payday), 'days_remaining', min(payday) - CAST(:as_of AS date),
    'amount_cents', sum(amount_cents), 'sources', jsonb_agg(jsonb_build_object(
        'income_source_id', id, 'from_name', from_name, 'expected_date', expected_date,
        'amount_cents', amount_cents) ORDER BY id, expected_date)) END AS next_payday
FROM next_day
"""


def paycheck_years(connection: Connection, ledger_id: UUID, as_of: date) -> list[int]:
    """Only refresh years near actual candidate dates (including shifted dates)."""
    return list(
        connection.scalars(
            text("""
        SELECT DISTINCT y.year FROM income_sources s
        CROSS JOIN LATERAL generate_series(
            EXTRACT(year FROM GREATEST(s.next_expected_date, CAST(:as_of AS date)))::integer - 1,
            EXTRACT(year FROM GREATEST(s.next_expected_date, CAST(:as_of AS date)))::integer + 1
        ) y(year)
        WHERE s.ledger_id = :ledger_id AND s.is_active IS TRUE
          AND s.deleted_at IS NULL AND s.income_type = 'paycheck'
          AND (s.frequency <> 'once' OR s.next_expected_date >= CAST(:as_of AS date))
        ORDER BY y.year
    """),
            {"ledger_id": ledger_id, "as_of": as_of},
        )
    )


def read_spending(connection: Connection, **params):
    return connection.execute(text(DASHBOARD_SQL), params).mappings().one()


def read_payday(connection: Connection, ledger_id: UUID, as_of: date):
    return connection.scalar(text(PAYDAY_SQL), {"ledger_id": ledger_id, "as_of": as_of})
