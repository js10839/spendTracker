from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

from sqlalchemy import create_engine, select

from app.db.tables import income_records, income_sources, metadata
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
        metadata.create_all(connection, tables=[income_sources, income_records])
        connection.exec_driver_sql("INSERT INTO ledgers (id) VALUES (?)", (ledger_id.hex,))

    with engine.connect() as db:
        expired_source = db.execute(income_sources.insert().values(ledger_id=ledger_id, income_type='other', expected_amount_cents=1000, frequency='once', reference_date=date(2026, 10, 25), next_expected_date=date(2026, 10, 25), is_active=True, deleted_at=cutoff - timedelta(days=1)).returning(income_sources)).one()
        active_source = db.execute(income_sources.insert().values(ledger_id=ledger_id, income_type='other', expected_amount_cents=1000, frequency='once', reference_date=date(2026, 10, 25), next_expected_date=date(2026, 10, 25), is_active=True).returning(income_sources)).one()
        live_record = db.execute(income_records.insert().values(ledger_id=ledger_id, income_source_id=expired_source.id, income_type='other', amount_cents=1000, received_at=date(2026, 10, 25), expected_date=date(2026, 10, 25)).returning(income_records)).one()
        expired_record = db.execute(income_records.insert().values(ledger_id=ledger_id, income_source_id=active_source.id, income_type='other', amount_cents=1000, received_at=date(2026, 10, 25), deleted_at=cutoff - timedelta(days=1)).returning(income_records)).one()
        recent_record = db.execute(income_records.insert().values(ledger_id=ledger_id, income_source_id=active_source.id, income_type='other', amount_cents=1000, received_at=date(2026, 10, 25), deleted_at=cutoff + timedelta(days=1)).returning(income_records)).one()
        expired_record_id, expired_source_id, recent_record_id, active_source_id = expired_record.id, expired_source.id, recent_record.id, active_source.id
        db.commit()

        assert repository.delete_expired_income_record_batch(db, cutoff=cutoff, batch_size=1000) == 1
        assert repository.delete_expired_income_source_batch(db, cutoff=cutoff, batch_size=1000) == 1
        db.commit()

        assert db.scalar(select(income_records.c.id).where(income_records.c.id == expired_record_id)) is None
        assert db.scalar(select(income_sources.c.id).where(income_sources.c.id == expired_source_id)) is None
        live_record = db.execute(select(income_records).where(income_records.c.id == live_record.id)).one_or_none()
        assert live_record.income_source_id is None
        assert live_record.expected_date == date(2026, 10, 25)
        assert db.scalar(select(income_records.c.id).where(income_records.c.id == recent_record_id)) == recent_record_id
        assert db.execute(select(income_sources).where(income_sources.c.id == active_source_id)).one_or_none() is not None

    engine.dispose()
