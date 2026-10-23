from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.income.schema import IncomeRecordCreate, IncomeRecordRead
from app.income.service import create_income_record
from app.ledgers.dependencies import get_user_ledger

router = APIRouter(prefix="/ledgers/{ledger_id}/income-records", tags=["income"])

@router.post("", status_code=status.HTTP_201_CREATED, response_model=IncomeRecordRead)
def add_income_record(data: IncomeRecordCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> IncomeRecordRead:
    """가계부 접근 권한을 확인한 뒤 실제 수입을 기록한다."""
    record = create_income_record(db, ledger_id=ledger.id, user_id=user_id, data=data)
    return IncomeRecordRead.model_validate(record)
