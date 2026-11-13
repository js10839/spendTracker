from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.engine import Connection
from sqlalchemy.orm import Session

from app.calendar import repository
from app.calendar.schema import CalendarRead
from app.integrations.bankday import BankdayUnavailable, fetch_bank_holidays


def ensure_bank_year(connection: Connection, year: int) -> None:
    """Preserve the income API's cache/stale-cache/unadjusted fallback policy."""
    cached = repository.find_bank_year(connection=connection, year=year)
    now = datetime.now(UTC)
    if cached and (
        year < now.year
        or now - cached["fetched_at"].replace(tzinfo=UTC) < timedelta(days=30)
    ):
        return
    try:
        holidays = fetch_bank_holidays(year)
    except BankdayUnavailable:
        return  # SQL uses stale cache, or the original expected date if absent.
    repository.upsert_bank_year(connection=connection, year=year, holidays=holidays, fetched_at=now)

def read_calendar(db: Session, ledger_id: UUID, user_id:UUID, anchor_date: date, payment_method_id: UUID | None = None) -> CalendarRead:
    """캘린더 조회와 휴일 캐시 갱신을 하나의 트랜잭션으로 처리한다."""
    try:
        result = _read_calendar(db.connection(), ledger_id=ledger_id, user_id=user_id, anchor_date=anchor_date, payment_method_id=payment_method_id)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise


def _read_calendar(
    connection: Connection,
    ledger_id: UUID,
    user_id: UUID,
    anchor_date: date,
    payment_method_id: UUID | None = None,
) -> CalendarRead:
    # Bound the public date domain so navigation and neighbouring holiday years
    # remain representable by both Python and the date-only client contract.
    if not 2 <= anchor_date.year <= 9997:
        raise HTTPException(
            status_code=422, detail="anchor_date year must be between 2 and 9997"
        )
    closing_day = None
    if payment_method_id is not None:
        card = repository.find_card(connection, user_id, payment_method_id)
        if card is None:
            raise HTTPException(status_code=404, detail="Credit card not found")
        closing_day = card["closing_day"]
    bounds = (
        connection.execute(repository.period_statement(anchor_date, closing_day))
        .mappings()
        .one()
    )
    if payment_method_id is None and repository.has_paycheck(connection, ledger_id):
        # Cover the period plus both neighbouring years for payday shifts across
        # New Year. The SQL walk stops at missing cache and uses the old fallback.
        for year in range(bounds["start_date"].year - 1, bounds["end_date"].year + 2):
            ensure_bank_year(connection, year)
    result = (
        connection.execute(
            repository.calendar_statement(
                ledger_id,
                user_id,
                bounds["start_date"],
                bounds["end_date"],
                payment_method_id,
            )
        )
        .mappings()
        .one()
    )
    return CalendarRead.model_validate(
        {
            "mode": "all" if payment_method_id is None else "card",
            "payment_method_id": payment_method_id,
            **bounds,
            **result,
        }
    )
