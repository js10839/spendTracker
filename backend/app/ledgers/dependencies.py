from typing import Annotated
from uuid import UUID

from fastapi import Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.service import require_ledger_access


def get_user_ledger(
    ledger_id: UUID,
    user_id: Annotated[UUID, Depends(get_current_user_id)],
    db: Annotated[Session, Depends(get_db)],
) -> Ledger:
    """경로의 가계부에 현재 사용자가 접근 가능한지 확인한다."""
    return require_ledger_access(db, ledger_id, user_id)
