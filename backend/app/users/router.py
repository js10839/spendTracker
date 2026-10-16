from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.session import get_db
from app.users.service import bootstrap_user

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/me/bootstrap")
def bootstrap_current_user(user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> dict[str, str]:
    """인증된 사용자의 앱 초기화를 실행하고 프로필 ID를 반환한다."""
    user = bootstrap_user(db, user_id=user_id, ledger_name="Personal")
    return {"user_id": str(user.id)}
