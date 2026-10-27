from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.day_notes.schema import DayNoteRead, DayNoteWrite
from app.day_notes.service import list_ledger_day_notes, save_day_note
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger

router = APIRouter(prefix="/ledgers/{ledger_id}/day-notes", tags=["day-notes"])


@router.get("", response_model=list[DayNoteRead])
def get_day_notes(start_date: date, end_date: date, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> list[DayNoteRead]:
    """접근 가능한 가계부에서 기간 내 내용이 있는 날짜 메모를 반환한다."""
    notes = list_ledger_day_notes(db, ledger.id, start_date, end_date)
    return [DayNoteRead.model_validate(note) for note in notes]


@router.put("/{note_date}", response_model=DayNoteRead | None)
def put_day_note(note_date: date, data: DayNoteWrite, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> DayNoteRead | None:
    """접근 가능한 가계부의 날짜 메모를 저장하거나 화면에서 비운다."""
    note = save_day_note(db, ledger.id, note_date, data.content)
    return DayNoteRead.model_validate(note) if note is not None else None