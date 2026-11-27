from datetime import date, datetime
from uuid import UUID

from sqlalchemy import delete, select, update
from sqlalchemy.engine import Connection, Row

from app.db.rows import update_row
from app.db.tables import income_records, income_sources, payment_methods


def find_user_payment_method(
    db: Connection, payment_method_id: UUID, user_id: UUID
) -> Row | None:
    """Applied to로 선택한 결제수단이 현재 사용자 소유인지 조회한다."""
    statement = select(payment_methods).where(
        payment_methods.c.id == payment_method_id, payment_methods.c.user_id == user_id
    )
    return db.execute(statement).one_or_none()


def add_income_source(
    db: Connection,
    ledger_id: UUID,
    from_name: str | None,
    expected_amount_cents: int,
    frequency: str,
    reference_date: date,
    next_expected_date: date,
    income_type: str = "paycheck",
    payment_method_id: UUID | None = None,
    memo: str | None = None,
) -> Row:
    """실제 입금과 분리된 일회성·반복 예정 수입을 저장한다."""
    statement = (
        income_sources.insert()
        .values(
            ledger_id=ledger_id,
            income_type=income_type,
            from_name=from_name,
            payment_method_id=payment_method_id,
            expected_amount_cents=expected_amount_cents,
            memo=memo,
            frequency=frequency,
            reference_date=reference_date,
            next_expected_date=next_expected_date,
        )
        .returning(income_sources)
    )
    return db.execute(statement).one()


def add_income_record(
    db: Connection,
    ledger_id: UUID,
    income_source_id: UUID | None,
    payment_method_id: UUID | None,
    income_type: str,
    from_name: str | None,
    amount_cents: int,
    received_at: date,
    memo: str | None,
    expected_date: date | None = None,
) -> Row:
    """실제 수입을 저장하고 예정 수입에서 확정했다면 원래 예정일도 보존한다."""
    statement = (
        income_records.insert()
        .values(
            ledger_id=ledger_id,
            income_source_id=income_source_id,
            payment_method_id=payment_method_id,
            income_type=income_type,
            from_name=from_name,
            amount_cents=amount_cents,
            received_at=received_at,
            memo=memo,
            expected_date=expected_date,
        )
        .returning(income_records)
    )
    return db.execute(statement).one()


def list_income_records(db: Connection, ledger_id: UUID) -> list[Row]:
    """가계부의 실제 수입 기록을 입금일 최신순으로 조회한다."""
    statement = (
        select(income_records)
        .where(
            income_records.c.ledger_id == ledger_id,
            income_records.c.deleted_at.is_(None),
        )
        .order_by(
            income_records.c.received_at.desc(), income_records.c.created_at.desc()
        )
    )
    return list(db.execute(statement))


def list_active_income_sources(db: Connection, ledger_id: UUID) -> list[Row]:
    """가계부의 입금 예정 항목을 지난 예정일을 포함해 날짜순으로 조회한다."""
    statement = (
        select(income_sources)
        .where(
            income_sources.c.ledger_id == ledger_id,
            income_sources.c.is_active.is_(True),
            income_sources.c.deleted_at.is_(None),
        )
        .order_by(income_sources.c.next_expected_date, income_sources.c.id)
    )
    return list(db.execute(statement))


def find_active_income_source(
    db: Connection, ledger_id: UUID, source_id: UUID
) -> Row | None:
    """해당 가계부에서 아직 활성 상태인 예정 수입을 찾는다."""
    statement = (
        select(income_sources)
        .where(
            income_sources.c.id == source_id,
            income_sources.c.ledger_id == ledger_id,
            income_sources.c.is_active.is_(True),
            income_sources.c.deleted_at.is_(None),
        )
        .with_for_update()
    )
    return db.execute(statement).one_or_none()


def find_restorable_income_source(
    db: Connection, ledger_id: UUID, source_id: UUID, cutoff: datetime
) -> Row | None:
    """해당 가계부에서 삭제 후 30일이 지나지 않은 예정 수입을 찾는다."""
    statement = select(income_sources).where(
        income_sources.c.id == source_id,
        income_sources.c.ledger_id == ledger_id,
        income_sources.c.deleted_at.is_not(None),
        income_sources.c.deleted_at > cutoff,
    )
    return db.execute(statement).one_or_none()


def find_income_source_for_undo(
    db: Connection, ledger_id: UUID, source_id: UUID
) -> Row | None:
    """확정 취소를 위해 비활성 상태의 일회성 예정 수입도 잠가서 조회한다."""
    statement = (
        select(income_sources)
        .where(
            income_sources.c.id == source_id,
            income_sources.c.ledger_id == ledger_id,
            income_sources.c.deleted_at.is_(None),
        )
        .with_for_update()
    )
    return db.execute(statement).one_or_none()


def update_income_source_state(
    db: Connection, source: Row, next_expected_date: date, is_active: bool
) -> Row:
    """확정 결과에 따라 다음 예정일과 활성 상태를 저장한다."""
    return update_row(
        db,
        income_sources,
        source,
        next_expected_date=next_expected_date,
        is_active=is_active,
    )


def find_income_record(db: Connection, ledger_id: UUID, record_id: UUID) -> Row | None:
    """해당 가계부에 속한 실제 수입 기록을 찾는다."""
    statement = select(income_records).where(
        income_records.c.id == record_id,
        income_records.c.ledger_id == ledger_id,
        income_records.c.deleted_at.is_(None),
    )
    return db.execute(statement).one_or_none()


def update_income_record(
    db: Connection,
    record: Row,
    amount_cents: int,
    received_at: date,
    memo: str | None,
    from_name: str | None,
    payment_method_id: UUID | None,
) -> Row:
    """검증된 실제 입금값을 저장하되 연결된 예정 규칙은 유지한다."""
    return update_row(
        db,
        income_records,
        record,
        amount_cents=amount_cents,
        received_at=received_at,
        memo=memo,
        from_name=from_name,
        payment_method_id=payment_method_id,
    )


def find_restorable_income_record(
    db: Connection, ledger_id: UUID, record_id: UUID, cutoff: datetime
) -> Row | None:
    """해당 가계부에서 삭제 후 30일이 지나지 않은 실제 수입을 찾는다."""
    statement = select(income_records).where(
        income_records.c.id == record_id,
        income_records.c.ledger_id == ledger_id,
        income_records.c.deleted_at.is_not(None),
        income_records.c.deleted_at > cutoff,
    )
    return db.execute(statement).one_or_none()


def update_income_source_details(
    db: Connection,
    source: Row,
    expected_amount_cents: int,
    frequency: str,
    reference_date: date,
    next_expected_date: date,
    memo: str | None,
    from_name: str | None,
    payment_method_id: UUID | None,
) -> Row:
    """검증된 예정 수입의 앞으로 적용할 설정을 저장한다."""
    return update_row(
        db,
        income_sources,
        source,
        expected_amount_cents=expected_amount_cents,
        frequency=frequency,
        reference_date=reference_date,
        next_expected_date=next_expected_date,
        memo=memo,
        from_name=from_name,
        payment_method_id=payment_method_id,
    )


def mark_income_record_deleted(
    db: Connection, record: Row, deleted_at: datetime
) -> None:
    """실제 수입을 복구 가능하도록 삭제 시각만 기록한다."""
    update_row(db, income_records, record, deleted_at=deleted_at)


def restore_income_record(db: Connection, record: Row) -> None:
    """실제 수입의 삭제 시각을 지워 다시 조회 가능하게 한다."""
    update_row(db, income_records, record, deleted_at=None)


def mark_income_source_deleted(
    db: Connection, source: Row, deleted_at: datetime
) -> None:
    """예정 수입을 숨기되 연결된 과거 실제 수입은 유지한다."""
    update_row(db, income_sources, source, deleted_at=deleted_at)


def restore_income_source(db: Connection, source: Row) -> None:
    """예정 수입의 삭제 시각을 지워 다시 조회 가능하게 한다."""
    update_row(db, income_sources, source, deleted_at=None)


def has_active_income_record_for_occurrence(
    db: Connection, ledger_id: UUID, source_id: UUID, expected_date: date
) -> bool:
    """같은 예정 회차에 이미 표시 중인 실제 수입이 있는지 확인한다."""
    statement = (
        select(income_records.c.id)
        .where(
            income_records.c.ledger_id == ledger_id,
            income_records.c.income_source_id == source_id,
            income_records.c.expected_date == expected_date,
            income_records.c.deleted_at.is_(None),
        )
        .limit(1)
    )
    return db.scalar(statement) is not None


def delete_expired_income_record_batch(
    db: Connection, cutoff: datetime, batch_size: int
) -> int:
    """보관 기간이 끝난 실제 수입을 한 묶음 잠가 영구 삭제한다."""
    statement = (
        select(income_records.c.id)
        .where(
            income_records.c.deleted_at.is_not(None),
            income_records.c.deleted_at <= cutoff,
        )
        .order_by(income_records.c.deleted_at, income_records.c.id)
        .limit(batch_size)
        .with_for_update()
    )
    record_ids = list(db.scalars(statement))
    if not record_ids:
        return 0

    db.execute(delete(income_records).where(income_records.c.id.in_(record_ids)))
    return len(record_ids)


def delete_expired_income_source_batch(
    db: Connection, cutoff: datetime, batch_size: int
) -> int:
    """만료된 예정 수입의 기록 참조를 해제한 뒤 규칙을 영구 삭제한다."""
    statement = (
        select(income_sources.c.id)
        .where(
            income_sources.c.deleted_at.is_not(None),
            income_sources.c.deleted_at <= cutoff,
        )
        .order_by(income_sources.c.deleted_at, income_sources.c.id)
        .limit(batch_size)
        .with_for_update()
    )
    source_ids = list(db.scalars(statement))
    if not source_ids:
        return 0

    db.execute(
        update(income_records)
        .where(income_records.c.income_source_id.in_(source_ids))
        .values(income_source_id=None)
    )
    db.execute(delete(income_sources).where(income_sources.c.id.in_(source_ids)))
    return len(source_ids)


def list_income_records_in_range(
    db: Connection, ledger_id: UUID, start_date: date, end_date: date
) -> list[Row]:
    """가계부의 지정 기간에 실제 입금된 삭제되지 않은 수입을 조회한다."""
    statement = (
        select(income_records)
        .where(
            income_records.c.ledger_id == ledger_id,
            income_records.c.deleted_at.is_(None),
            income_records.c.received_at >= start_date,
            income_records.c.received_at <= end_date,
        )
        .order_by(income_records.c.received_at, income_records.c.id)
    )
    return list(db.execute(statement))
