from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_active_user_id, get_current_user_id
from app.db.session import get_db
from app.users.schema import (
    UserBootstrapRead,
    UserOnboardingComplete,
    UserProfileRead,
    UserProfileUpdate,
)
from app.users.service import (
    bootstrap_user,
    complete_user_onboarding,
    delete_account,
    get_user_profile,
    update_user_profile,
)

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/me/bootstrap")
def bootstrap_current_user(user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> UserBootstrapRead:
    """초기화된 사용자와 가입 정보 입력 필요 여부를 반환한다."""
    user = bootstrap_user(db, user_id=user_id, ledger_name="Personal")
    return UserBootstrapRead(user_id=user_id, onboarding_required=not user.onboarding_completed)

@router.get("/me", response_model=UserProfileRead)
def get_current_user_profile(user_id: Annotated[UUID, Depends(get_active_user_id)], db: Annotated[Session, Depends(get_db)]) -> UserProfileRead:
    """인증된 사용자의 앱 프로필을 반환한다."""
    user = get_user_profile(db, user_id=user_id)
    return UserProfileRead.model_validate(user)

@router.patch("/me", response_model=UserProfileRead)
def patch_current_user_profile(data: UserProfileUpdate, user_id: Annotated[UUID, Depends(get_active_user_id)], db: Annotated[Session, Depends(get_db)]) -> UserProfileRead:
    """인증된 사용자의 표시 이름을 수정한다."""
    user = update_user_profile(db, user_id=user_id, nickname=data.nickname)
    return UserProfileRead.model_validate(user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_current_user(user_id: Annotated[UUID, Depends(get_current_user_id)]) -> Response:
    """인증된 사용자의 계정 삭제를 요청하거나 재시도한다."""
    await delete_account(user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.post("/me/onboarding/complete", response_model=UserProfileRead)
def complete_onboarding(data: UserOnboardingComplete, user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> UserProfileRead:
    """인증된 사용자의 가입 정보를 완료하고 저장된 프로필을 반환한다."""
    user = complete_user_onboarding(db=db, user_id=user_id, nickname=data.nickname)
    return UserProfileRead.model_validate(user)



