from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.auth.dependencies import get_active_user_id
from app.dashboard.schema import DashboardRead
from app.dashboard.service import read_dashboard
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger

router = APIRouter(prefix="/ledgers/{ledger_id}/dashboard", tags=["dashboard"])


@router.get("", response_model=DashboardRead)
def get_dashboard(
    as_of: date,
    ledger: Annotated[Ledger, Depends(get_user_ledger)],
    user_id: Annotated[UUID, Depends(get_active_user_id)],
    db: Annotated[Session, Depends(get_db)],
    month: date | None = None,
    year: Annotated[int | None, Query(ge=2, le=9997)] = None,
    payment_method_id: UUID | None = None,
    category_start: date | None = None,
    category_end: date | None = None,
) -> DashboardRead:
    """Return SQL-aggregated spending, card cycles, charts and the next paycheck."""
    return read_dashboard(
        db,
        ledger_id=ledger.id,
        user_id=user_id,
        as_of=as_of,
        month=month,
        year=year,
        payment_method_id=payment_method_id,
        category_start=category_start,
        category_end=category_end,
    )
