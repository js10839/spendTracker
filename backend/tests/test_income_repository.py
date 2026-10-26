from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.db import models  # noqa: F401 - FK 대상 테이블을 metadata에 등록한다.
from app.db.base import Base
from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.income import repository


def test_expired_income_cleanup_preserves_live_records_and_unlinks_source() -> None:
    """FK 제약을 켠 DB에서 만료 기록만 지우고 남은 기록의 예정 참조를 해제한다."""
    engine = create_engine("sqlite:///:memory:")
    ledger_id = uuid4()
    cutoff = datetime.now(UTC) - timedelta(days=30)
    with engine.begin() as connection:
        connection.exec_driver_sql("PRAGMA foreign_keys=ON")
        connection.exec_driver_sql("CREATE TABLE ledgers (id CHAR(32) PRIMARY KEY)")
        connection.exec_driver_sql("CREATE TABLE payment_methods (id CHAR(32) PRIMARY KEY)")
        Base.metadata.create_all(connection, tables=[IncomeSource.__table__, IncomeRecord.__table__])
        connection.exec_driver_sql("INSERT INTO ledgers (id) VALUES (?)", (ledger_id.hex,))

    with Session(engine) as db:
        expired_source = IncomeSource(ledger_id=ledger_id, income_type="other", expected_amount_cents=1000, frequency="once", reference_date=date(2026, 10, 25), next_expected_date=date(2026, 10, 25), is_active=True, deleted_at=cutoff - timedelta(days=1))
        active_source = IncomeSource(ledger_id=ledger_id, income_type="other", expected_amount_cents=1000, frequency="once", reference_date=date(2026, 10, 25), next_expected_date=date(2026, 10, 25), is_active=True)
        db.add_all((expired_source, active_source))
        db.flush()
        live_record = IncomeRecord(ledger_id=ledger_id, income_source_id=expired_source.id, income_type="other", amount_cents=1000, received_at=date(2026, 10, 25), expected_date=date(2026, 10, 25))
        expired_record = IncomeRecord(ledger_id=ledger_id, income_source_id=active_source.id, income_type="other", amount_cents=1000, received_at=date(2026, 10, 25), deleted_at=cutoff - timedelta(days=1))
        recent_record = IncomeRecord(ledger_id=ledger_id, income_source_id=active_source.id, income_type="other", amount_cents=1000, received_at=date(2026, 10, 25), deleted_at=cutoff + timedelta(days=1))
        db.add_all((live_record, expired_record, recent_record))
        db.flush()
        expired_record_id, expired_source_id, recent_record_id, active_source_id = expired_record.id, expired_source.id, recent_record.id, active_source.id
        db.commit()

        assert repository.delete_expired_income_record_batch(db, cutoff=cutoff, batch_size=1000) == 1
        assert repository.delete_expired_income_source_batch(db, cutoff=cutoff, batch_size=1000) == 1
        db.commit()

        assert db.scalar(select(IncomeRecord.id).where(IncomeRecord.id == expired_record_id)) is None
        assert db.scalar(select(IncomeSource.id).where(IncomeSource.id == expired_source_id)) is None
        db.refresh(live_record)
        assert live_record.income_source_id is None
        assert live_record.expected_date == date(2026, 10, 25)
        assert db.scalar(select(IncomeRecord.id).where(IncomeRecord.id == recent_record_id)) == recent_record_id
        assert db.get(IncomeSource, active_source_id) is not None

    engine.dispose()
