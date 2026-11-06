from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.day_note import DayNote


def find_day_note(db: Session, ledger_id: UUID, note_date: date) -> DayNote | None:
    """가계부의 특정 날짜 메모를 조회한다."""
    statement = select(DayNote).where(DayNote.ledger_id == ledger_id, DayNote.note_date == note_date)
    return db.scalars(statement).one_or_none()

def list_day_notes_in_range(db: Session, ledger_id: UUID, start_date: date, end_date: date) -> list[DayNote]:
    """가계부의 지정 기간에 저장된 날짜 메모를 조회한다."""
    statement = select(DayNote).where(DayNote.ledger_id == ledger_id, DayNote.note_date >= start_date, DayNote.note_date <= end_date, DayNote.content != "",).order_by(DayNote.note_date)
    return list(db.scalars(statement))

def add_day_note(db: Session, ledger_id: UUID, note_date: date, content: str) -> DayNote:
    """새 날짜 메모를 세션에 추가한다."""
    note = DayNote(ledger_id=ledger_id, note_date=note_date, content=content)
    db.add(note)
    db.flush()
    return note

def update_day_note(db: Session, note: DayNote, content: str) -> DayNote:
    """기존 날짜 메모 내용을 갱신한다."""
    note.content = content
    db.flush()
    return note