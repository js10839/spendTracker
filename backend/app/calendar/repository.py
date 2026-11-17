"""Parameterized PostgreSQL queries for the calendar.

Aggregate independent collections before joining the date spine so items and
income cannot multiply transaction totals or dot counts.
"""

import json
from datetime import date, datetime
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.engine import Connection

PERIOD_SQL = """
WITH anchor AS (
    SELECT CAST(:anchor_date AS date) AS day,
           CAST(date_trunc('month', CAST(:anchor_date AS date)) AS date) AS month,
           CAST(:closing_day AS integer) AS closing_day
), ending AS (
    SELECT *, CASE WHEN closing_day IS NOT NULL AND day >
        month + LEAST(closing_day, EXTRACT(day FROM month + INTERVAL '1 month - 1 day')::integer) - 1
        THEN (month + INTERVAL '1 month')::date ELSE month END AS ending_month
    FROM anchor
), bounds AS (
    SELECT CASE WHEN closing_day IS NULL THEN month ELSE
        (ending_month - INTERVAL '1 month')::date
        + LEAST(closing_day, EXTRACT(day FROM ending_month - INTERVAL '1 day')::integer)
        END AS start_date,
        CASE WHEN closing_day IS NULL THEN (month + INTERVAL '1 month')::date - 1 ELSE
        ending_month + LEAST(closing_day,
            EXTRACT(day FROM ending_month + INTERVAL '1 month - 1 day')::integer) - 1
        END AS end_date
    FROM ending
)
SELECT start_date, end_date, start_date - 1 AS previous_anchor_date,
       end_date + 1 AS next_anchor_date
FROM bounds
"""


def period_statement(anchor_date: date, closing_day: int | None):
    return text(PERIOD_SQL).bindparams(anchor_date=anchor_date, closing_day=closing_day)


def find_card(connection: Connection, user_id: UUID, method_id: UUID):
    return (
        connection.execute(
            text("""
            SELECT closing_day FROM payment_methods
            WHERE id = :method_id AND user_id = :user_id AND type = 'credit'
        """),
            {"method_id": method_id, "user_id": user_id},
        )
        .mappings()
        .one_or_none()
    )


def find_bank_year(connection: Connection, year: int):
    return (
        connection.execute(
            text(
                "SELECT year, holidays, fetched_at FROM bank_calendar_years WHERE year = :year"
            ),
            {"year": year},
        )
        .mappings()
        .one_or_none()
    )


def upsert_bank_year(
    connection: Connection, year: int, holidays: set[date], fetched_at: datetime
) -> None:
    connection.execute(
        text("""
            INSERT INTO bank_calendar_years (year, holidays, fetched_at)
            VALUES (:year, CAST(:holidays AS json), :fetched_at)
            ON CONFLICT (year) DO UPDATE
            SET holidays = EXCLUDED.holidays, fetched_at = EXCLUDED.fetched_at
        """),
        {
            "year": year,
            "holidays": json.dumps(sorted(day.isoformat() for day in holidays)),
            "fetched_at": fetched_at,
        },
    )


def has_paycheck(connection: Connection, ledger_id: UUID) -> bool:
    return connection.scalar(
        text("""
            SELECT EXISTS (
                SELECT 1 FROM income_sources
                WHERE ledger_id = :ledger_id AND is_active IS TRUE
                  AND deleted_at IS NULL AND income_type = 'paycheck'
            )
        """),
        {"ledger_id": ledger_id},
    )


CALENDAR_SQL = """
WITH RECURSIVE
params AS (
    SELECT CAST(:ledger_id AS uuid) AS ledger_id, CAST(:user_id AS uuid) AS user_id,
           CAST(:start AS date) AS start_date, CAST(:end AS date) AS end_date,
           CAST(:payment_method_id AS uuid) AS payment_method_id
),
wallet AS (
    SELECT m.* FROM payment_methods m, params p WHERE m.user_id = p.user_id
),
calendar_transactions AS (
    SELECT t.* FROM transactions t, params p
    WHERE t.ledger_id = p.ledger_id AND t.deleted_at IS NULL
      AND t.transacted_at BETWEEN p.start_date AND p.end_date
      AND (p.payment_method_id IS NULL OR t.payment_method_id = p.payment_method_id)
),
aggregated_items AS (
    SELECT i.transaction_id, jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.name, 'category_id', i.category_id,
        'amount_cents', i.amount_cents) ORDER BY i.created_at, i.id) AS items
    FROM transaction_items i
    WHERE i.transaction_id IN (SELECT id FROM calendar_transactions)
    GROUP BY i.transaction_id
),
daily_transactions AS (
    SELECT t.transacted_at AS date, jsonb_agg(jsonb_build_object(
        'id', t.id, 'ledger_id', t.ledger_id, 'payment_method_id', t.payment_method_id,
        'merchant', t.merchant, 'transacted_at', t.transacted_at, 'memo', t.memo,
        'source', t.source, 'total_cents', t.total_cents, 'tax_cents', t.tax_cents,
        'tip_cents', t.tip_cents, 'items', COALESCE(i.items, '[]'::jsonb)
        ) ORDER BY t.id) AS transactions, sum(t.total_cents) AS spending_cents
    FROM calendar_transactions t LEFT JOIN aggregated_items i ON i.transaction_id = t.id
    GROUP BY t.transacted_at
),
counts AS (
    SELECT transacted_at AS date, payment_method_id, count(*) AS transaction_count
    FROM calendar_transactions GROUP BY transacted_at, payment_method_id
),
daily_dots AS (
    SELECT c.date, jsonb_agg(jsonb_build_object(
        'payment_method_id', c.payment_method_id,
        'label', COALESCE(w.name, 'Unknown payment method'), 'color', w.color,
        'transaction_count', c.transaction_count) ORDER BY c.payment_method_id) AS dots
    FROM counts c LEFT JOIN wallet w ON w.id = c.payment_method_id GROUP BY c.date
),
-- Include the first business day after the window: a later paycheck can shift
-- back into the displayed period. Stop at missing cache to preserve fallback.
horizon(day) AS (
    SELECT end_date + 1 FROM params
    UNION ALL
    SELECT h.day + 1 FROM horizon h
    JOIN bank_calendar_years b ON b.year = EXTRACT(year FROM h.day)
    WHERE EXTRACT(isodow FROM h.day) > 5
       OR b.holidays::jsonb @> jsonb_build_array(h.day::text)
),
payday_walk AS (
    SELECT s.id AS income_source_id, s.income_type, s.from_name,
           s.payment_method_id, s.expected_amount_cents AS amount_cents, s.memo,
           d.day::date AS expected_date, d.day::date AS display_date
    FROM income_sources s CROSS JOIN params p
    CROSS JOIN generate_series(p.start_date::timestamp,
        (SELECT max(day) FROM horizon)::timestamp, INTERVAL '1 day') AS d(day)
    WHERE s.ledger_id = p.ledger_id AND s.is_active IS TRUE AND s.deleted_at IS NULL
      AND (p.payment_method_id IS NULL OR
           (s.income_type = 'cashback' AND s.payment_method_id = p.payment_method_id))
      AND d.day::date >= s.next_expected_date
      AND (d.day::date = s.next_expected_date
           OR (s.frequency = 'biweekly' AND (d.day::date - s.next_expected_date) % 14 = 0)
           OR (s.frequency = 'monthly' AND d.day::date =
               date_trunc('month', d.day)::date + LEAST(
                   EXTRACT(day FROM s.reference_date)::integer,
                   EXTRACT(day FROM date_trunc('month', d.day)
                       + INTERVAL '1 month - 1 day')::integer) - 1))
      AND (s.frequency <> 'monthly' OR d.day::date = s.next_expected_date
           OR date_trunc('month', d.day) > date_trunc('month', s.next_expected_date))
    UNION ALL
    SELECT w.income_source_id, w.income_type, w.from_name, w.payment_method_id,
           w.amount_cents, w.memo, w.expected_date, w.display_date - 1
    FROM payday_walk w
    JOIN bank_calendar_years b ON b.year = EXTRACT(year FROM w.display_date)
    WHERE w.income_type = 'paycheck' AND (EXTRACT(isodow FROM w.display_date) > 5
        OR b.holidays::jsonb @> jsonb_build_array(w.display_date::text))
),
resolved_paydays AS (
    SELECT w.*, CASE WHEN w.income_type = 'paycheck' AND b.year IS NULL
                    THEN w.expected_date ELSE w.display_date END AS resolved_date
    FROM payday_walk w
    LEFT JOIN bank_calendar_years b ON b.year = EXTRACT(year FROM w.display_date)
    WHERE w.income_type <> 'paycheck' OR b.year IS NULL
       OR (EXTRACT(isodow FROM w.display_date) <= 5
           AND NOT (b.holidays::jsonb @> jsonb_build_array(w.display_date::text)))
),
income_entries AS (
    SELECT 'planned' AS status, w.income_source_id, NULL::uuid AS income_record_id,
           w.income_type, w.from_name, w.payment_method_id, w.amount_cents,
           w.expected_date, NULL::date AS received_at, w.resolved_date AS display_date, w.memo
    FROM resolved_paydays w, params p
    WHERE w.resolved_date BETWEEN p.start_date AND p.end_date
    UNION ALL
    SELECT 'received', r.income_source_id, r.id, r.income_type, r.from_name,
           r.payment_method_id, r.amount_cents, r.expected_date, r.received_at,
           r.received_at, r.memo
    FROM income_records r, params p
    WHERE r.ledger_id = p.ledger_id AND r.deleted_at IS NULL
      AND r.received_at BETWEEN p.start_date AND p.end_date
      AND (p.payment_method_id IS NULL OR
           (r.income_type = 'cashback' AND r.payment_method_id = p.payment_method_id))
),
daily_income AS (
    SELECT i.display_date AS date,
           jsonb_agg(to_jsonb(i) ORDER BY i.status, i.income_source_id,
                     i.income_record_id, i.expected_date) AS income,
           sum(CASE WHEN i.status = 'received' THEN i.amount_cents ELSE 0 END)
               AS received_income_cents
    FROM income_entries i GROUP BY i.display_date
),
dates AS (
    SELECT d.day::date AS date FROM params p
    CROSS JOIN generate_series(p.start_date::timestamp, p.end_date::timestamp,
                               INTERVAL '1 day') AS d(day)
),
method_details AS (
    SELECT w.id, w.type, w.closing_day, jsonb_build_object(
        'id', w.id, 'name', w.name, 'type', w.type, 'color', w.color,
        'closing_day', w.closing_day) AS details
    FROM wallet w
),
closings AS (
    SELECT d.date, jsonb_agg(w.details ORDER BY w.id) AS closing_cards
    FROM dates d CROSS JOIN params p JOIN method_details w
      ON w.type = 'credit' AND (p.payment_method_id IS NULL OR w.id = p.payment_method_id)
     AND d.date = date_trunc('month', d.date)::date + LEAST(w.closing_day,
         EXTRACT(day FROM date_trunc('month', d.date) + INTERVAL '1 month - 1 day')::integer) - 1
    GROUP BY d.date
),
active_notes AS (
    SELECT n.* FROM day_notes n, params p
    WHERE n.ledger_id = p.ledger_id AND n.note_date BETWEEN p.start_date AND p.end_date
      AND btrim(n.content) <> ''
),
daily AS (
    SELECT d.date, COALESCE(t.transactions, '[]'::jsonb) AS transactions,
           COALESCE(dots.dots, '[]'::jsonb) AS dots,
           COALESCE(i.income, '[]'::jsonb) AS income,
           COALESCE(c.closing_cards, '[]'::jsonb) AS closing_cards,
           CASE WHEN n.id IS NOT NULL THEN jsonb_build_object(
               'id', n.id, 'ledger_id', n.ledger_id, 'note_date', n.note_date,
               'content', n.content) END AS note,
           COALESCE(t.spending_cents, 0) AS spending_cents,
           COALESCE(i.received_income_cents, 0) AS received_income_cents
    FROM dates d LEFT JOIN daily_transactions t ON t.date = d.date
    LEFT JOIN daily_dots dots ON dots.date = d.date
    LEFT JOIN daily_income i ON i.date = d.date
    LEFT JOIN closings c ON c.date = d.date
    LEFT JOIN active_notes n ON n.note_date = d.date
)
SELECT (SELECT COALESCE(jsonb_agg(details ORDER BY id), '[]'::jsonb)
        FROM method_details) AS payment_methods,
       (SELECT COALESCE(jsonb_agg(details ORDER BY id), '[]'::jsonb)
        FROM method_details WHERE type = 'credit') AS cards,
       (SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.date), '[]'::jsonb)
        FROM daily d) AS days
"""


def calendar_statement(
    ledger_id: UUID,
    user_id: UUID,
    start: date,
    end: date,
    payment_method_id: UUID | None,
):
    return text(CALENDAR_SQL).bindparams(
        ledger_id=ledger_id,
        user_id=user_id,
        start=start,
        end=end,
        payment_method_id=payment_method_id,
    )
