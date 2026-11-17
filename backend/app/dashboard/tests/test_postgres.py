"""Actual raw-SQL results against retained PostgreSQL test2 fixtures."""

from datetime import date

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.dashboard import repository
from app.dashboard.schema import NextPayday
from app.db.session import get_db
from app.main import app


def test_empty_ledger_returns_zero_buckets_and_all_cards(samples):
    result = samples.read()
    assert result.spending_30_days.total_cents == 0
    assert len(result.monthly_spending.buckets) == 30
    assert len(result.yearly_spending.buckets) == 12
    assert all(b.total_cents == 0 for b in result.monthly_spending.buckets)
    assert all(b.total_cents == 0 for b in result.yearly_spending.buckets)
    assert len(result.card_statements) == 2
    assert all(
        c.total_cents == 0 and not c.top_categories for c in result.card_statements
    )
    assert len(result.cycle_pace) == 3
    assert result.next_payday is None
    assert result.category_breakdown.categories == []


def test_rolling_window_is_inclusive_and_ledger_scoped(samples):
    samples.tx("before", "2026-10-14", 900)
    samples.tx("first", "2026-10-15", 100)
    samples.tx("today", "2026-11-13", 200, items=(("Food", 50), ("Food", 150)))
    samples.tx("cash", "2026-11-01", 50, method="cash")
    samples.tx("future", "2026-11-14", 999)
    samples.tx("deleted", "2026-11-13", 999, deleted=True)
    samples.tx("foreign", "2026-11-13", 999, method="foreign", ledger="other_ledger")
    result = samples.read()
    assert result.spending_30_days.start_date == date(2026, 10, 15)
    assert result.spending_30_days.total_cents == 350
    assert sum(b.total_cents for b in result.monthly_spending.buckets) == 250
    assert sum(b.total_cents for b in result.yearly_spending.buckets) == 1250


def test_statement_cycle_top_three_categories_and_pie_reconcile(samples):
    samples.tx(
        "receipt",
        "2026-11-13",
        1200,
        items=(("Food", 400), ("Travel", 300), ("Shopping", 200), ("Other", 100)),
    )
    samples.tx("previous", "2026-11-12", 600, items=(("Other", 600),))
    samples.tx("future", "2026-11-14", 9000, items=(("Other", 9000),))
    result = samples.read()
    card = next(
        c for c in result.card_statements if c.payment_method_id == samples.id("card")
    )
    assert (card.start_date, card.end_date, card.spent_through) == (
        date(2026, 11, 13),
        date(2026, 12, 12),
        date(2026, 11, 13),
    )
    assert card.total_cents == 1200
    assert [c.amount_cents for c in card.top_categories] == [400, 300, 200]
    assert [c.category_id for c in card.top_categories] == [
        samples.id("Food"),
        samples.id("Travel"),
        samples.id("Shopping"),
    ]
    pie = result.category_breakdown
    assert pie.total_cents == 1800
    assert sum(c.amount_cents for c in pie.categories) == 1800
    assert next(c for c in pie.categories if c.category_id is None).amount_cents == 200


def test_cycle_pace_compares_same_elapsed_days(samples):
    for key, day, amount in (
        ("a", "2026-10-13", 100),
        ("b", "2026-10-20", 200),
        ("c", "2026-10-21", 400),
        ("d", "2026-11-13", 300),
        ("e", "2026-11-20", 500),
        ("future", "2026-11-21", 999),
    ):
        samples.tx(key, day, amount)
    samples.tx("cash", "2026-10-01", 50, method="cash")
    result = samples.read("2026-11-20")
    card = next(
        c for c in result.cycle_pace if c.payment_method_id == samples.id("card")
    )
    assert card.elapsed_days == card.previous_elapsed_days == 8
    assert card.current.total_cents == 800
    assert card.previous.total_cents == 300
    assert card.previous.end_date == date(2026, 10, 20)
    all_mode = next(c for c in result.cycle_pace if c.mode == "all")
    assert all_mode.elapsed_days == 20
    assert all_mode.previous.total_cents == 350


@pytest.mark.parametrize(
    "as_of,previous_days", [("2026-03-31", 28), ("2024-03-31", 29)]
)
def test_short_previous_month_is_clamped(samples, as_of, previous_days):
    result = samples.read(as_of)
    card = next(
        c for c in result.cycle_pace if c.payment_method_id == samples.id("second")
    )
    assert card.elapsed_days == 31
    assert card.previous_elapsed_days == previous_days
    assert card.previous.end_date.month == 2
    assert card.previous.end_date.day == previous_days
    february = samples.read(as_of[:4] + "-02-15")
    assert len(february.monthly_spending.buckets) == previous_days


def test_selected_card_filters_charts_and_pie_but_not_global_summaries(samples):
    samples.tx("card", "2026-11-13", 100)
    samples.tx("second", "2026-11-13", 200, method="second")
    samples.tx("cash", "2026-11-13", 300, method="cash")
    result = samples.read(payment_method_id=samples.id("card"))
    assert sum(b.total_cents for b in result.monthly_spending.buckets) == 100
    assert sum(b.total_cents for b in result.yearly_spending.buckets) == 100
    assert result.category_breakdown.total_cents == 100
    assert result.spending_30_days.total_cents == 600
    assert len(result.card_statements) == 2
    assert len(result.cycle_pace) == 3
    assert (
        next(
            c
            for c in result.card_statements
            if c.payment_method_id == samples.id("second")
        ).total_cents
        == 200
    )
    with pytest.raises(HTTPException) as error:
        samples.read(payment_method_id=samples.id("foreign"))
    assert error.value.status_code == 404
    with pytest.raises(HTTPException) as error:
        samples.read(payment_method_id=samples.id("cash"))
    assert error.value.status_code == 404


def test_month_year_and_category_windows_can_be_selected_independently(samples):
    samples.tx("sep", "2025-09-30", 100)
    samples.tx("oct", "2025-10-01", 200)
    samples.tx("today", "2026-11-13", 300)
    result = samples.read(
        month=date(2025, 10, 18),
        year=2025,
        category_start=date(2025, 9, 30),
        category_end=date(2025, 9, 30),
    )
    assert len(result.monthly_spending.buckets) == 31
    assert result.monthly_spending.buckets[0].total_cents == 200
    assert sum(b.total_cents for b in result.yearly_spending.buckets) == 300
    assert result.category_breakdown.total_cents == 100
    assert result.spending_30_days.total_cents == 300


def test_next_payday_combines_same_day_sources_and_ignores_other_income(samples):
    samples.plan("job1", "2026-11-13", amount=2000)
    samples.plan("job2", "2026-11-13", amount=3000)
    samples.plan("later", "2026-11-20", amount=9999)
    samples.plan("old", "2026-10-01", amount=9999)
    samples.plan("cashback", "2026-11-13", amount=9999, income_type="cashback")
    samples.plan("other", "2026-11-13", amount=9999, income_type="other")
    samples.plan("inactive", "2026-11-13", amount=9999, is_active=False)
    samples.plan("deleted", "2026-11-13", amount=9999, deleted_at=date(2026, 11, 1))
    samples.plan(
        "foreign", "2026-11-13", amount=9999, ledger_id=samples.id("other_ledger")
    )
    payday = samples.read().next_payday
    assert payday.date == date(2026, 11, 13)
    assert payday.days_remaining == 0
    assert payday.amount_cents == 5000
    assert len(payday.sources) == 2


def test_biweekly_skips_overdue_and_already_shifted_occurrences(samples):
    samples.plan("biweekly", "2026-11-01", frequency="biweekly")
    # Nov 15 shifts to Nov 13, which is past as of Nov 14. Next is Nov 29 -> 27.
    payday = samples.read("2026-11-14").next_payday
    assert payday.date == date(2026, 11, 27)
    assert payday.sources[0].expected_date == date(2026, 11, 29)
    assert payday.days_remaining == 13


def test_monthly_payday_retains_original_day_and_skips_past_adjusted_date(samples):
    samples.plan("monthly", "2026-01-31", frequency="monthly")
    assert samples.read("2026-02-26").next_payday.date == date(2026, 2, 27)
    payday = samples.read("2026-02-28").next_payday
    assert payday.date == date(2026, 3, 31)
    assert payday.sources[0].expected_date == date(2026, 3, 31)


def test_payday_crosses_year_and_bank_holiday(samples):
    samples.plan("newyear", "2027-01-01")
    payday = samples.read("2026-12-30").next_payday
    assert payday.date == date(2026, 12, 31)
    assert payday.days_remaining == 1
    assert payday.sources[0].expected_date == date(2027, 1, 1)


def test_missing_bank_cache_keeps_expected_date(samples):
    samples.plan("uncached", "2030-06-01")  # Saturday; no 2030 cache in test2.
    payday = NextPayday.model_validate(
        repository.read_payday(samples.db, samples.id("ledger"), date(2030, 5, 31))
    )
    assert payday.date == date(2030, 6, 1)


def test_refund_amounts_stay_signed_and_total_is_not_multiplied(samples):
    samples.tx("purchase", "2026-11-13", 1000, items=(("Food", 600), ("Travel", 400)))
    samples.tx("refund", "2026-11-13", -200, items=(("Food", -200),))
    result = samples.read()
    assert result.spending_30_days.total_cents == 800
    assert result.category_breakdown.total_cents == 800
    assert sorted(c.amount_cents for c in result.category_breakdown.categories) == [
        400,
        400,
    ]


def test_non_usd_rejected(samples):
    samples.tx("eur", "2026-11-13", 100, currency="EUR")
    with pytest.raises(HTTPException) as error:
        samples.read()
    assert error.value.status_code == 422


def test_real_api_response_with_auth_and_ledger_dependencies(samples):
    samples.tx("receipt", "2026-11-13", 1234)
    original = app.dependency_overrides.copy()
    db = Session(bind=samples.db, join_transaction_mode="create_savepoint")
    app.dependency_overrides[get_current_user_id] = lambda: samples.id("user")
    app.dependency_overrides[get_db] = lambda: db
    try:
        with TestClient(app) as client:
            response = client.get(
                f"/ledgers/{samples.id('ledger')}/dashboard",
                params={"as_of": "2026-11-13"},
            )
        assert response.status_code == 200
        assert response.json()["spending_30_days"]["total_cents"] == 1234
        assert response.json()["currency"] == "USD"
        denied = client.get(
            f"/ledgers/{samples.id('other_ledger')}/dashboard",
            params={"as_of": "2026-11-13"},
        )
        assert denied.status_code in (403, 404)
    finally:
        db.close()
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original)


def test_query_plan_uses_one_spending_aggregation_statement(samples):
    params = {
        "ledger_id": samples.id("ledger"),
        "user_id": samples.id("user"),
        "as_of": date(2026, 11, 13),
        "month": date(2026, 11, 1),
        "year": 2026,
        "category_start": None,
        "category_end": None,
        "payment_method_id": None,
    }
    plan = samples.db.scalar(
        text("EXPLAIN (ANALYZE, FORMAT JSON) " + repository.DASHBOARD_SQL), params
    )
    assert plan[0]["Plan"]["Actual Rows"] == 1
