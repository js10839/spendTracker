from calendar import monthrange
from datetime import date, timedelta
from typing import Literal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.income import repository
from app.income.schema import IncomePlanConfirm, IncomePlanCreate, IncomeRecordCreate


def calculate_next_expected_date(reference_date: date, frequency: Literal["biweekly", "monthly"], anchor_day: int | None = None) -> date:
    """현재 예정일 다음 날짜를 계산하고 월간 일정은 최초 일자를 유지한다."""
    if frequency == "biweekly":
        return reference_date + timedelta(days=14)

    year = reference_date.year + (reference_date.month // 12)
    month = (reference_date.month % 12) + 1
    day = min(anchor_day if anchor_day is not None else reference_date.day, monthrange(year=year, month=month)[1])
    return date(year=year, month=month, day=day)

def confirm_income_plan(db: Session, ledger_id: UUID, source_id: UUID, data: IncomePlanConfirm) -> IncomeRecord:
    """예정일 한 회차를 실제 수입으로 기록하고 다음 예정 상태를 갱신한다."""
    try:
        source = repository.find_active_income_source(db, ledger_id=ledger_id, source_id=source_id)
        if source is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income plan not found")
        if source.next_expected_date != data.expected_date:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Income plan date has changed")

        amount_cents = data.amount_cents if data.amount_cents is not None else source.expected_amount_cents
        record = repository.add_income_record(db, ledger_id=ledger_id, income_source_id=source.id, payment_method_id=source.payment_method_id, income_type=source.income_type, from_name=source.from_name, amount_cents=amount_cents, received_at=data.received_at, memo=source.memo)

        is_active = source.frequency != "once"
        next_expected_date = source.next_expected_date
        if is_active:
            next_expected_date = calculate_next_expected_date(source.next_expected_date, source.frequency, anchor_day=source.reference_date.day)
        repository.update_income_source_state(db, source=source, next_expected_date=next_expected_date, is_active=is_active)

        db.commit()
        return record
    except Exception:
        db.rollback()
        raise

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

def create_income_plan(db: Session, ledger_id: UUID, user_id: UUID, data: IncomePlanCreate) -> IncomeSource:
    """결제수단 소유권을 확인하고 실제 입금과 분리된 예정 수입을 저장한다."""
    payment_method_id = None
    if data.applied_to is not None:
        method = repository.find_user_payment_method(db, payment_method_id=data.applied_to, user_id=user_id)
        if method is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")
        payment_method_id = method.id

    try:
        source = repository.add_income_source(db, ledger_id=ledger_id, from_name=data.from_name, expected_amount_cents=data.expected_amount_cents, frequency=data.frequency, reference_date=data.expected_date, next_expected_date=data.expected_date, income_type=data.income_type, payment_method_id=payment_method_id, memo=data.memo)
        db.commit()
        return source
    except Exception:
        db.rollback()
        raise

def list_ledger_income_sources(db: Session, ledger_id: UUID) -> list[IncomeSource]:
    """가계부의 활성 예정 수입 규칙을 조회한다."""
    return repository.list_active_income_sources(db, ledger_id=ledger_id)

def list_ledger_income_records(db: Session, ledger_id: UUID) -> list[IncomeRecord]:
    """가계부에 실제로 입금된 수입 기록을 조회한다."""
    return repository.list_income_records(db, ledger_id=ledger_id)