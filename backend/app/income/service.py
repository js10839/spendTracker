from calendar import monthrange
from datetime import date, timedelta
from typing import Literal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models.income_record import IncomeRecord
from app.income import repository
from app.income.schema import IncomeRecordCreate


def calculate_next_expected_date(reference_date: date, frequency: Literal["biweekly", "monthly"]) -> date:
    """기준일 다음의 반복 Paycheck 예상일을 계산한다."""
    if frequency=="biweekly":
        return reference_date + timedelta(days=14)

    year = reference_date.year + (reference_date.month // 12)
    month = (reference_date.month % 12) + 1
    day = min(reference_date.day, monthrange(year=year, month=month)[1])
    return date(year=year, month=month, day=day)

def create_income_record(db: Session, ledger_id: UUID, user_id: UUID, data:IncomeRecordCreate) -> IncomeRecord:
    """유형별 입력과 결제수단 소유권을 확인하고 수입을 저장한다."""
    payment_method_id = None
    if isinstance(data.applied_to, UUID):
        method = repository.find_user_payment_method(db, payment_method_id=data.applied_to, user_id=user_id)
        if method is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")
        payment_method_id = method.id

    try:
        income_source_id = None
        if data.income_type == "paycheck" and data.frequency != "never":
            source = repository.add_income_source(db, ledger_id=ledger_id, from_name=data.from_name, expected_amount_cents=data.amount_cents, frequency=data.frequency, reference_date=data.received_at, next_expected_date=calculate_next_expected_date(data.received_at, data.frequency))
            income_source_id = source.id

        record = repository.add_income_record(db, ledger_id=ledger_id, income_source_id=income_source_id, payment_method_id=payment_method_id, income_type=data.income_type, from_name=data.from_name, amount_cents=data.amount_cents, received_at=data.received_at, memo=data.memo)
        db.commit()
        return record
    except Exception:
        db.rollback()
        raise
