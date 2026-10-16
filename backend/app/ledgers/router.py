from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.session import get_db
from app.ledgers.service import list_user_ledgers

router = APIRouter(prefix="/ledgers", tags=["ledgers"])

@router.get("")
def get_ledgers(user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> list[dict[str,str]]:
    """현재 사용자가 접근할 수 있는 가계부의 ID와 이름을 반환한다."""
    ledgers = list_user_ledgers(db, user_id=user_id)
    return [{"id": str(ledger.id), "name": ledger.name} for ledger in ledgers]