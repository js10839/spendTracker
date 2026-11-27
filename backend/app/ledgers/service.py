from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.engine import Connection, Row

from app.ledgers import repository


def require_ledger_access(db: Connection, ledger_id: UUID, user_id: UUID) -> Row:
    """멤버십이 없는 가계부는 존재 여부를 드러내지 않고 404로 처리한다."""
    ledger = repository.find_member_ledger(db, ledger_id, user_id)
    if ledger is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Ledger not found"
        )
    return ledger

def list_user_ledgers(db: Connection, user_id:UUID) -> list[Row]:
    """사용자가 접근할 수 있는 가계부 목록을 반환한다."""
    return repository.list_member_ledgers(db, user_id)