from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.income.schema import (
    IncomePlanConfirm,
    IncomePlanCreate,
    IncomePlanRead,
    IncomePlanUpdate,
    IncomeRecordCreate,
    IncomeRecordRead,
    IncomeRecordUpdate,
)
from app.income.service import (
    confirm_income_plan,
    create_income_plan,
    create_income_record,
    list_ledger_income_records,
    list_ledger_income_sources,
    update_ledger_income_plan,
    update_ledger_income_record,
)
from app.ledgers.dependencies import get_user_ledger

router = APIRouter(prefix="/ledgers/{ledger_id}", tags=["income"])

@router.post("/income-records", status_code=status.HTTP_201_CREATED, response_model=IncomeRecordRead)
def add_income_record(data: IncomeRecordCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> IncomeRecordRead:
    """가계부 접근 권한을 확인한 뒤 실제 수입을 기록한다."""
    record = create_income_record(db, ledger_id=ledger.id, user_id=user_id, data=data)
    return IncomeRecordRead.model_validate(record)

@router.get("/income-records", response_model=list[IncomeRecordRead])
def get_income_records(ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> list[IncomeRecordRead]:
    """접근 가능한 가계부에서 실제로 받은 수입 기록을 반환한다."""
    records = list_ledger_income_records(db, ledger_id=ledger.id)
    return [IncomeRecordRead.model_validate(record) for record in records]

@router.post("/income-plans", status_code=status.HTTP_201_CREATED, response_model=IncomePlanRead)
def add_income_plan(data: IncomePlanCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> IncomePlanRead:
    """가계부 접근 권한을 확인한 뒤 예정 수입을 저장한다."""
    source = create_income_plan(db, ledger_id=ledger.id, user_id=user_id, data=data)
    return IncomePlanRead.model_validate(source)

@router.get("/income-plans", response_model=list[IncomePlanRead])
def get_income_plans(ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> list[IncomePlanRead]:
    """접근 가능한 가계부의 활성 예정 수입을 반환한다."""
    sources = list_ledger_income_sources(db, ledger_id=ledger.id)
    return [IncomePlanRead.model_validate(source) for source in sources]

@router.post("/income-plans/{source_id}/confirm", status_code=status.HTTP_201_CREATED, response_model=IncomeRecordRead)
def confirm_planned_income(source_id: UUID, data: IncomePlanConfirm, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> IncomeRecordRead:
    """접근 가능한 가계부의 예정 입금을 실제 수입으로 확정한다."""
    record = confirm_income_plan(db, ledger_id=ledger.id, source_id=source_id, data=data)
    return IncomeRecordRead.model_validate(record)

@router.put("/income-records/{record_id}", response_model=IncomeRecordRead)
def edit_income_record(record_id: UUID, data: IncomeRecordUpdate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> IncomeRecordRead:
    """가계부 접근 권한을 확인한 뒤 실제 수입 기록을 수정한다."""
    record = update_ledger_income_record(db, ledger_id=ledger.id, user_id=user_id, record_id=record_id, data=data)
    return IncomeRecordRead.model_validate(record)

@router.put("/income-plans/{source_id}", response_model=IncomePlanRead)
def edit_income_plan(source_id: UUID, data: IncomePlanUpdate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> IncomePlanRead:
    """가계부 접근 권한을 확인한 뒤 활성 예정 수입의 설정을 수정한다."""
    source = update_ledger_income_plan(db, ledger_id=ledger.id, user_id=user_id, source_id=source_id, data=data)
    return IncomePlanRead.model_validate(source)
