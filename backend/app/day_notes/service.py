from datetime import date
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.day_notes import repository
from app.db.models.day_note import DayNote


def list_ledger_day_notes(db: Session, ledger_id: UUID, start_date: date, end_date: date) -> list[DayNote]:
    """달력 기간에 표시할 내용이 있는 날짜 메모를 조회한다."""
    if start_date > end_date:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="start_date must be on or before end_date")
    return repository.list_day_notes_in_range(db, ledger_id, start_date, end_date)


def save_day_note(db: Session, ledger_id: UUID, note_date: date, content: str) -> DayNote | None:
    """메모를 생성·수정하고 빈 내용은 달력에서 보이지 않게 한다."""
    note = repository.find_day_note(db, ledger_id, note_date)
    if note is None and content == "":
        return None

    try:
        if note is None:
            note = repository.add_day_note(db, ledger_id, note_date, content)
        else:
            note = repository.update_day_note(db, note, content)
        db.commit()
        return note if content != "" else None
    except Exception:
        db.rollback()
        raise