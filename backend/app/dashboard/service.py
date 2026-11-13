"""Validate dashboard selections and coordinate SQL reads/holiday cache writes."""

from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.engine import Connection
from sqlalchemy.orm import Session

from app.dashboard import repository
from app.dashboard.repository import find_card
from app.dashboard.schema import DashboardRead
from app.integrations.bankday import BankdayUnavailable, fetch_bank_holidays


def ensure_bank_year(connection: Connection, year: int) -> None:
    """Use the existing stale-cache/unadjusted policy with dashboard-owned SQL."""
    cached = repository.find_bank_year(connection, year)
    now = datetime.now(UTC)
    if cached and (
        year < now.year
        or now - cached["fetched_at"].replace(tzinfo=UTC) < timedelta(days=30)
    ):
        return
    try:
        holidays = fetch_bank_holidays(year)
    except BankdayUnavailable:
        return
    repository.upsert_bank_year(connection, year, holidays, now)


def _validate_date(value: date) -> None:
    if not 2 <= value.year <= 9997:
        raise HTTPException(422, "Date years must be between 2 and 9997")


def _read_dashboard(
    connection: Connection,
    *,
    ledger_id: UUID,
    user_id: UUID,
    as_of: date,
    month: date | None = None,
    year: int | None = None,
    payment_method_id: UUID | None = None,
    category_start: date | None = None,
    category_end: date | None = None,
) -> DashboardRead:
    month = month or as_of
    year = year if year is not None else as_of.year
    _validate_date(as_of)
    _validate_date(month)
    if not 2 <= year <= 9997:
        raise HTTPException(422, "year must be between 2 and 9997")
    if (category_start is None) != (category_end is None):
        raise HTTPException(422, "Provide both category_start and category_end")
    if category_start is not None and category_end is not None:
        _validate_date(category_start)
        _validate_date(category_end)
        if not 0 <= (category_end - category_start).days <= 365:
            raise HTTPException(422, "Category range must contain 1 to 366 days")
    if (
        payment_method_id is not None
        and find_card(connection, user_id, payment_method_id) is None
    ):
        raise HTTPException(404, "Credit card not found")

    # Default range calculation stays in SQL alongside all other date selection.
    result = repository.read_spending(
        connection,
        ledger_id=ledger_id,
        user_id=user_id,
        as_of=as_of,
        month=month,
        year=year,
        payment_method_id=payment_method_id,
        category_start=category_start,
        category_end=category_end,
    )
    if result["unsupported_currency"]:
        raise HTTPException(422, "Dashboard supports USD transactions only")
    for holiday_year in repository.paycheck_years(connection, ledger_id, as_of):
        if 1 <= holiday_year <= 9999:
            ensure_bank_year(connection, holiday_year)
    return DashboardRead.model_validate(
        {
            "as_of": as_of,
            "currency": "USD",
            "payment_method_id": payment_method_id,
            **result,
            "next_payday": repository.read_payday(connection, ledger_id, as_of),
        }
    )


def read_dashboard(db: Session, **params) -> DashboardRead:
    """Commit only successful requests, including any bank-calendar cache updates."""
    try:
        result = _read_dashboard(db.connection(), **params)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
