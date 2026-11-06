from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class DayNoteWrite(BaseModel):
    """선택한 날짜에 저장할 메모 내용을 받는다."""

    content: str


class DayNoteRead(BaseModel):
    """저장된 가계부 날짜 메모를 반환한다."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    ledger_id: UUID
    note_date: date
    content: str