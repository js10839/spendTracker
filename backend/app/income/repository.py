from datetime import date, datetime
from uuid import UUID

from sqlalchemy import delete, select, update
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

def add_income_record(db: Session, ledger_id: UUID, income_source_id: UUID | None, payment_method_id: UUID | None, income_type: str, from_name: str | None, amount_cents: int, received_at: date, memo: str | None, expected_date: date | None = None) -> IncomeRecord:
    """실제 수입을 저장하고 예정 수입에서 확정했다면 원래 예정일도 보존한다."""
    record = IncomeRecord(ledger_id=ledger_id, income_source_id=income_source_id, payment_method_id=payment_method_id, income_type=income_type, from_name=from_name, amount_cents=amount_cents, received_at=received_at, memo=memo, expected_date=expected_date)
    db.add(record)
    db.flush()
    return record

def list_income_records(db: Session, ledger_id: UUID) -> list[IncomeRecord]:
    """가계부의 실제 수입 기록을 입금일 최신순으로 조회한다."""
    statement = select(IncomeRecord).where(IncomeRecord.ledger_id==ledger_id, IncomeRecord.deleted_at.is_(None)).order_by(IncomeRecord.received_at.desc(), IncomeRecord.created_at.desc())
    return list(db.scalars(statement=statement))

def list_active_income_sources(db: Session, ledger_id: UUID) -> list[IncomeSource]:
    """가계부의 입금 예정 항목을 지난 예정일을 포함해 날짜순으로 조회한다."""
    statement = select(IncomeSource).where(IncomeSource.ledger_id == ledger_id, IncomeSource.is_active.is_(True), IncomeSource.deleted_at.is_(None)).order_by(IncomeSource.next_expected_date, IncomeSource.id)
    return list(db.scalars(statement))

def find_active_income_source(db: Session, ledger_id: UUID, source_id: UUID) -> IncomeSource | None:
    """해당 가계부에서 아직 활성 상태인 예정 수입을 찾는다."""
    statement = select(IncomeSource).where(
        IncomeSource.id == source_id,
        IncomeSource.ledger_id == ledger_id,
        IncomeSource.is_active.is_(True),
        IncomeSource.deleted_at.is_(None),
    ).with_for_update()
    return db.scalars(statement).one_or_none()

def find_restorable_income_source(db: Session, ledger_id: UUID, source_id: UUID, cutoff: datetime) -> IncomeSource | None:
    """해당 가계부에서 삭제 후 30일이 지나지 않은 예정 수입을 찾는다."""
    statement = select(IncomeSource).where(IncomeSource.id == source_id, IncomeSource.ledger_id == ledger_id, IncomeSource.deleted_at.is_not(None), IncomeSource.deleted_at > cutoff)
    return db.scalars(statement).one_or_none()

def find_income_source_for_undo(db: Session, ledger_id: UUID, source_id: UUID) -> IncomeSource | None:
    """확정 취소를 위해 비활성 상태의 일회성 예정 수입도 잠가서 조회한다."""
    statement = select(IncomeSource).where(IncomeSource.id == source_id, IncomeSource.ledger_id == ledger_id, IncomeSource.deleted_at.is_(None)).with_for_update()
    return db.scalars(statement).one_or_none()

def update_income_source_state(db: Session, source: IncomeSource, next_expected_date: date, is_active: bool) -> None:
    """확정 결과에 따라 다음 예정일과 활성 상태를 저장한다."""
    source.next_expected_date = next_expected_date
    source.is_active = is_active
    db.flush()

def find_income_record(db: Session, ledger_id: UUID, record_id: UUID) -> IncomeRecord | None:
    """해당 가계부에 속한 실제 수입 기록을 찾는다."""
    statement = select(IncomeRecord).where(IncomeRecord.id == record_id, IncomeRecord.ledger_id == ledger_id, IncomeRecord.deleted_at.is_(None))
    return db.scalars(statement).one_or_none()

def update_income_record(db: Session, record: IncomeRecord, amount_cents: int, received_at: date, memo: str | None, from_name: str | None, payment_method_id: UUID | None) -> IncomeRecord:
    """검증된 실제 입금값을 저장하되 연결된 예정 규칙은 유지한다."""
    record.amount_cents = amount_cents
    record.received_at = received_at
    record.memo = memo
    record.from_name = from_name
    record.payment_method_id = payment_method_id
    db.flush()
    return record

def find_restorable_income_record(db: Session, ledger_id: UUID, record_id: UUID, cutoff: datetime) -> IncomeRecord | None:
    """해당 가계부에서 삭제 후 30일이 지나지 않은 실제 수입을 찾는다."""
    statement = select(IncomeRecord).where(IncomeRecord.id == record_id, IncomeRecord.ledger_id == ledger_id, IncomeRecord.deleted_at.is_not(None), IncomeRecord.deleted_at > cutoff)
    return db.scalars(statement).one_or_none()

def update_income_source_details(db: Session, source: IncomeSource, expected_amount_cents: int, frequency: str, reference_date: date, next_expected_date: date, memo: str | None, from_name: str | None, payment_method_id: UUID | None) -> IncomeSource:
    """검증된 예정 수입의 앞으로 적용할 설정을 저장한다."""
    source.expected_amount_cents = expected_amount_cents
    source.frequency = frequency
    source.reference_date = reference_date
    source.next_expected_date = next_expected_date
    source.memo = memo
    source.from_name = from_name
    source.payment_method_id = payment_method_id
    db.flush()
    return source

def mark_income_record_deleted(db: Session, record: IncomeRecord, deleted_at: datetime) -> None:
    """실제 수입을 복구 가능하도록 삭제 시각만 기록한다."""
    record.deleted_at = deleted_at
    db.flush()

def restore_income_record(db: Session, record: IncomeRecord) -> None:
    """실제 수입의 삭제 시각을 지워 다시 조회 가능하게 한다."""
    record.deleted_at = None
    db.flush()

def mark_income_source_deleted(db: Session, source: IncomeSource, deleted_at: datetime) -> None:
    """예정 수입을 숨기되 연결된 과거 실제 수입은 유지한다."""
    source.deleted_at = deleted_at
    db.flush()

def restore_income_source(db: Session, source: IncomeSource) -> None:
    """예정 수입의 삭제 시각을 지워 다시 조회 가능하게 한다."""
    source.deleted_at = None
    db.flush()

def has_active_income_record_for_occurrence(db: Session, ledger_id: UUID, source_id: UUID, expected_date: date) -> bool:
    """같은 예정 회차에 이미 표시 중인 실제 수입이 있는지 확인한다."""
    statement = select(IncomeRecord.id).where(IncomeRecord.ledger_id == ledger_id, IncomeRecord.income_source_id == source_id, IncomeRecord.expected_date == expected_date, IncomeRecord.deleted_at.is_(None)).limit(1)
    return db.scalar(statement) is not None

def delete_expired_income_record_batch(db: Session, cutoff: datetime, batch_size: int) -> int:
    """보관 기간이 끝난 실제 수입을 한 묶음 잠가 영구 삭제한다."""
    statement = select(IncomeRecord.id).where(IncomeRecord.deleted_at.is_not(None), IncomeRecord.deleted_at <= cutoff).order_by(IncomeRecord.deleted_at, IncomeRecord.id).limit(batch_size).with_for_update()
    record_ids = list(db.scalars(statement))
    if not record_ids:
        return 0

    db.execute(delete(IncomeRecord).where(IncomeRecord.id.in_(record_ids)))
    return len(record_ids)

def delete_expired_income_source_batch(db: Session, cutoff: datetime, batch_size: int) -> int:
    """만료된 예정 수입의 기록 참조를 해제한 뒤 규칙을 영구 삭제한다."""
    statement = select(IncomeSource.id).where(IncomeSource.deleted_at.is_not(None), IncomeSource.deleted_at <= cutoff).order_by(IncomeSource.deleted_at, IncomeSource.id).limit(batch_size).with_for_update()
    source_ids = list(db.scalars(statement))
    if not source_ids:
        return 0

    db.execute(update(IncomeRecord).where(IncomeRecord.income_source_id.in_(source_ids)).values(income_source_id=None))
    db.execute(delete(IncomeSource).where(IncomeSource.id.in_(source_ids)))
    return len(source_ids)
