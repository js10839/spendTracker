from datetime import date
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.day_notes import repository, service
from app.db.models.day_note import DayNote


def test_day_note_can_be_edited_and_cleared() -> None:
    """같은 날짜 메모를 수정하고 비우면 달력에서는 숨긴다."""
    engine = create_engine("sqlite+pysqlite:///:memory:")
    DayNote.__table__.create(engine)
    ledger_id = uuid4()
    note_date = date(2026, 10, 26)

    with Session(engine, expire_on_commit=False) as db:
        assert service.save_day_note(db, ledger_id, note_date, "") is None
        assert repository.find_day_note(db, ledger_id, note_date) is None

        created = service.save_day_note(db, ledger_id, note_date, "첫 메모")
        updated = service.save_day_note(db, ledger_id, note_date, "수정한 메모")

        assert updated.id == created.id
        assert updated.content == "수정한 메모"

        assert service.save_day_note(db, ledger_id, note_date, "") is None
        assert service.list_ledger_day_notes(db, ledger_id, note_date, note_date) == []
        assert repository.find_day_note(db, ledger_id, note_date).content == ""
