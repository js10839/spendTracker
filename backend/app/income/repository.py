from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.db.models.payment_method import PaymentMethod


def find_user_payment_method(db: Session, payment_method_id: UUID, user_id: UUID) -> PaymentMethod | None:
    """Applied to로 선택한 결제수단이 현재 사용자 소유인지 조회한다."""
    statement = select(PaymentMethod).where(PaymentMethod.id==payment_method_id, PaymentMethod.user_id==user_id)
    return db.execute(statement=statement).scalar_one_or_none()

def add_income_source(db: Session, ledger_id: UUID, from_name: str, expected_amount_cents: int, frequency: str, reference_date: date, next_expected_date: date) -> IncomeSource:
    """반복 Paycheck 규칙을 추가하고 생성된 ID를 확보한다."""
    source = IncomeSource(ledger_id=ledger_id, from_name=from_name, expected_amount_cents=expected_amount_cents, frequency=frequency, reference_date=reference_date, next_expected_date=next_expected_date)
    db.add(source)
    db.flush()
    return source

def add_income_record(db: Session, ledger_id: UUID, income_source_id: UUID | None, payment_method_id: UUID | None, income_type: str, from_name: str | None, amount_cents: int, received_at: date, memo: str | None) -> IncomeRecord:
    """실제로 받은 금액을 기록하고 생성된 ID를 확보한다."""
    record = IncomeRecord(ledger_id=ledger_id, income_source_id=income_source_id, payment_method_id=payment_method_id, income_type=income_type, from_name=from_name, amount_cents=amount_cents, received_at=received_at, memo=memo)
    db.add(record)
    db.flush()
    return record
