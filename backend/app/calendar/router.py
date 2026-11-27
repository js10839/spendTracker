from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.engine import Connection, Row

from app.auth.dependencies import get_active_user_id
from app.calendar.schema import CalendarRead
from app.calendar.service import read_calendar
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger

router = APIRouter(prefix="/ledgers/{ledger_id}/calendar", tags=["calendar"])


@router.get("", response_model=CalendarRead)
def get_calendar(
    anchor_date: date,
    ledger: Annotated[Row, Depends(get_user_ledger)],
    user_id: Annotated[UUID, Depends(get_active_user_id)],
    db: Annotated[Connection, Depends(get_db)],
    payment_method_id: UUID | None = None,
) -> CalendarRead:
    """Return a complete month/card cycle, grouped and aggregated in PostgreSQL."""
    return read_calendar(db, ledger_id=ledger.id, anchor_date=anchor_date, payment_method_id=payment_method_id, user_id=user_id)
