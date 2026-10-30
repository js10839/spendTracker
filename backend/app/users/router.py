from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.session import get_db
from app.users.schema import UserProfileRead, UserProfileUpdate
from app.users.service import bootstrap_user, get_user_profile, update_user_profile

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/me/bootstrap")
def bootstrap_current_user(user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> dict[str, str]:
    """인증된 사용자의 앱 초기화를 실행하고 프로필 ID를 반환한다."""
    user = bootstrap_user(db, user_id=user_id, ledger_name="Personal")
    return {"user_id": str(user.id)}

@router.get("/me", response_model=UserProfileRead)
def get_current_user_profile(user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> UserProfileRead:
    """인증된 사용자의 앱 프로필을 반환한다."""
    user = get_user_profile(db, user_id=user_id)
    return UserProfileRead.model_validate(user)

@router.patch("/me", response_model=UserProfileRead)
def patch_current_user_profile(data: UserProfileUpdate, user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> UserProfileRead:
    """인증된 사용자의 표시 이름을 수정한다."""
    user = update_user_profile(db, user_id=user_id, nickname=data.nickname)
    return UserProfileRead.model_validate(user)
