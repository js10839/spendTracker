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

def add_income_source(db: Session, ledger_id: UUID, from_name: str | None, expected_amount_cents: int, frequency: str, reference_date: date, next_expected_date: date, income_type: str = "paycheck", payment_method_id: UUID | None = None, memo: str | None = None) -> IncomeSource:
    """실제 입금과 분리된 일회성·반복 예정 수입을 저장한다."""
    source = IncomeSource(ledger_id=ledger_id, income_type=income_type, from_name=from_name, payment_method_id=payment_method_id, expected_amount_cents=expected_amount_cents, memo=memo, frequency=frequency, reference_date=reference_date, next_expected_date=next_expected_date)
    db.add(source)
    db.flush()
    return source

def add_income_record(db: Session, ledger_id: UUID, income_source_id: UUID | None, payment_method_id: UUID | None, income_type: str, from_name: str | None, amount_cents: int, received_at: date, memo: str | None) -> IncomeRecord:
    """실제로 받은 금액을 기록하고 생성된 ID를 확보한다."""
    record = IncomeRecord(ledger_id=ledger_id, income_source_id=income_source_id, payment_method_id=payment_method_id, income_type=income_type, from_name=from_name, amount_cents=amount_cents, received_at=received_at, memo=memo)
    db.add(record)
    db.flush()
    return record

def list_income_records(db: Session, ledger_id: UUID) -> list[IncomeRecord]:
    """가계부의 실제 수입 기록을 입금일 최신순으로 조회한다."""
    statement = select(IncomeRecord).where(IncomeRecord.ledger_id==ledger_id).order_by(IncomeRecord.received_at.desc(), IncomeRecord.created_at.desc())
    return list(db.scalars(statement=statement))

def list_active_income_sources(db: Session, ledger_id: UUID) -> list[IncomeSource]:
    """가계부의 입금 예정 항목을 지난 예정일을 포함해 날짜순으로 조회한다."""
    statement = select(IncomeSource).where(IncomeSource.ledger_id == ledger_id, IncomeSource.is_active.is_(True)).order_by(IncomeSource.next_expected_date, IncomeSource.id)
    return list(db.scalars(statement))

def find_active_income_source(db: Session, ledger_id: UUID, source_id: UUID) -> IncomeSource | None:
    """해당 가계부에서 아직 활성 상태인 예정 수입을 찾는다."""
    statement = select(IncomeSource).where(
        IncomeSource.id == source_id,
        IncomeSource.ledger_id == ledger_id,
        IncomeSource.is_active.is_(True),
    ).with_for_update()
    return db.scalars(statement).one_or_none()

def update_income_source_state(db: Session, source: IncomeSource, next_expected_date: date, is_active: bool) -> None:
    """확정 결과에 따라 다음 예정일과 활성 상태를 저장한다."""
    source.next_expected_date = next_expected_date
    source.is_active = is_active
    db.flush()