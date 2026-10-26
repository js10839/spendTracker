from calendar import monthrange
from datetime import UTC, date, datetime, timedelta
from time import sleep
from typing import Literal
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.income import repository
from app.income.schema import (
    IncomePlanConfirm,
    IncomePlanCreate,
    IncomePlanUpdate,
    IncomeRecordCreate,
    IncomeRecordUpdate,
)


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
        record = repository.add_income_record(db, ledger_id=ledger_id, income_source_id=source.id, payment_method_id=source.payment_method_id, income_type=source.income_type, from_name=source.from_name, amount_cents=amount_cents, received_at=data.received_at, memo=source.memo, expected_date=data.expected_date)

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

def update_ledger_income_record(db: Session, ledger_id: UUID, user_id: UUID, record_id: UUID, data: IncomeRecordUpdate) -> IncomeRecord:
    """기존 수입 유형과 예정 규칙을 유지하며 실제 입금 내용을 수정한다."""
    try:
        record = repository.find_income_record(db, ledger_id=ledger_id, record_id=record_id)
        if record is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income record not found")

        payment_method_id = None
        if record.income_type == "paycheck":
            if data.from_name is None or data.applied_to is not None:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Paycheck requires From and cannot have Applied to")
        elif record.income_type == "cashback":
            if data.from_name is not None or data.applied_to is None:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Cashback requires a registered payment method")
            method = repository.find_user_payment_method(db, payment_method_id=data.applied_to, user_id=user_id)
            if method is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")
            payment_method_id = method.id
        elif data.from_name is not None or data.applied_to is not None:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Other accepts only amount, date, and note")

        updated = repository.update_income_record(db, record=record, amount_cents=data.amount_cents, received_at=data.received_at, memo=data.memo, from_name=data.from_name, payment_method_id=payment_method_id)
        db.commit()
        return updated
    except Exception:
        db.rollback()
        raise

def update_ledger_income_plan(db: Session, ledger_id: UUID, user_id: UUID, source_id: UUID, data: IncomePlanUpdate) -> IncomeSource:
    """활성 예정 수입의 앞으로 적용할 금액과 일정을 수정한다."""
    try:
        source = repository.find_active_income_source(db, ledger_id=ledger_id, source_id=source_id)
        if source is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income plan not found")

        payment_method_id = None
        if source.income_type == "paycheck":
            if data.from_name is None or data.applied_to is not None:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Paycheck requires From and cannot have Applied to")
        elif source.income_type == "cashback":
            if data.from_name is not None or data.applied_to is None or data.frequency != "once":
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Cashback requires a payment method and cannot repeat")
            method = repository.find_user_payment_method(db, payment_method_id=data.applied_to, user_id=user_id)
            if method is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")
            payment_method_id = method.id
        elif data.from_name is not None or data.applied_to is not None or data.frequency != "once":
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Other accepts only amount, date, and note")

        reference_date = source.reference_date
        if data.expected_date != source.next_expected_date or data.frequency != source.frequency:
            reference_date = data.expected_date

        updated = repository.update_income_source_details(db, source=source, expected_amount_cents=data.expected_amount_cents, frequency=data.frequency, reference_date=reference_date, next_expected_date=data.expected_date, memo=data.memo, from_name=data.from_name, payment_method_id=payment_method_id)
        db.commit()
        return updated
    except Exception:
        db.rollback()
        raise

def soft_delete_income_record(db: Session, ledger_id: UUID, record_id: UUID) -> None:
    """실제 수입을 숨기고 30일 복구를 위해 삭제 시각을 남긴다."""
    record = repository.find_income_record(db, ledger_id=ledger_id, record_id=record_id)
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income record not found")

    try:
        repository.mark_income_record_deleted(db, record=record, deleted_at=datetime.now(UTC))
        db.commit()
    except Exception:
        db.rollback()
        raise

def soft_delete_income_plan(db: Session, ledger_id: UUID, source_id: UUID) -> None:
    """예정 수입을 숨기고 이미 확정된 실제 기록은 유지한다."""
    source = repository.find_active_income_source(db, ledger_id=ledger_id, source_id=source_id)
    if source is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income plan not found")

    try:
        repository.mark_income_source_deleted(db, source=source, deleted_at=datetime.now(UTC))
        db.commit()
    except Exception:
        db.rollback()
        raise

def restore_deleted_income_plan_for_admin(db: Session, ledger_id: UUID, source_id: UUID) -> None:
    """관리자 운영 절차에서 삭제 후 30일 이내인 예정 수입을 복구한다."""
    cutoff = datetime.now(UTC) - timedelta(days=30)
    source = repository.find_restorable_income_source(db, ledger_id=ledger_id, source_id=source_id, cutoff=cutoff)
    if source is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restorable income plan not found")

    try:
        repository.restore_income_source(db, source=source)
        db.commit()
    except Exception:
        db.rollback()
        raise

def restore_deleted_income_record_for_admin(db: Session, ledger_id: UUID, record_id: UUID) -> None:
    """관리자 운영 절차에서 30일 이내의 실제 수입을 중복 없이 복구한다."""
    cutoff = datetime.now(UTC) - timedelta(days=30)
    record = repository.find_restorable_income_record(db, ledger_id=ledger_id, record_id=record_id, cutoff=cutoff)
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restorable income record not found")

    try:
        if record.income_source_id is not None and record.expected_date is not None:
            source = repository.find_income_source_for_undo(db, ledger_id=ledger_id, source_id=record.income_source_id)
            if source is not None and source.is_active and source.next_expected_date == record.expected_date:
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Income occurrence is open")
            if repository.has_active_income_record_for_occurrence(db, ledger_id=ledger_id, source_id=record.income_source_id, expected_date=record.expected_date):
                raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Income occurrence already confirmed")

        repository.restore_income_record(db, record=record)
        db.commit()
    except Exception:
        db.rollback()
        raise

def undo_income_confirmation(db: Session, ledger_id: UUID, record_id: UUID) -> IncomeSource:
    """방금 확정한 수입 기록을 숨기고 해당 예정 회차를 다시 연다."""
    try:
        record = repository.find_income_record(db, ledger_id=ledger_id, record_id=record_id)
        if record is None or record.income_source_id is None or record.expected_date is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Confirmed income record not found")

        source = repository.find_income_source_for_undo(db, ledger_id=ledger_id, source_id=record.income_source_id)
        if source is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Income plan not found")

        if source.frequency == "once":
            can_undo = not source.is_active and source.next_expected_date == record.expected_date
        else:
            next_date = calculate_next_expected_date(record.expected_date, source.frequency, anchor_day=source.reference_date.day)
            can_undo = source.is_active and source.next_expected_date == next_date

        if not can_undo:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Income plan has changed since confirmation")

        repository.mark_income_record_deleted(db, record=record, deleted_at=datetime.now(UTC))
        repository.update_income_source_state(db, source=source, next_expected_date=record.expected_date, is_active=True)
        db.commit()
        return source
    except Exception:
        db.rollback()
        raise

def purge_expired_income(db: Session, batch_size: int = 1000, pause_seconds: float = 0.1) -> tuple[int, int]:
    """30일이 지난 실제 수입과 예정 규칙을 순서대로 묶음 정리한다."""
    cutoff = datetime.now(UTC) - timedelta(days=30)
    records_deleted = 0
    sources_deleted = 0

    while True:
        try:
            count = repository.delete_expired_income_record_batch(db, cutoff=cutoff, batch_size=batch_size)
            db.commit()
        except Exception:
            db.rollback()
            raise

        records_deleted += count
        if count < batch_size:
            break
        sleep(pause_seconds)

    while True:
        try:
            count = repository.delete_expired_income_source_batch(db, cutoff=cutoff, batch_size=batch_size)
            db.commit()
        except Exception:
            db.rollback()
            raise

        sources_deleted += count
        if count < batch_size:
            break
        sleep(pause_seconds)

    return records_deleted, sources_deleted