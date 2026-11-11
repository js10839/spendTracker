from uuid import UUID

from pydantic import BaseModel, ConfigDict


class UserProfileRead(BaseModel):
    """인증된 사용자의 앱 프로필을 반환한다."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nickname: str | None
    plan: str

class UserProfileUpdate(BaseModel):
    """사용자가 프로필에서 변경할 표시 이름을 받는다."""

    nickname: str

class UserBootstrapRead(BaseModel):
    """초기화된 사용자와 가입 정보 입력 필요 여부를 반환한다."""

    user_id: UUID
    onboarding_required: bool

class UserOnboardingComplete(BaseModel):
    """가입 정보 입력 완료 시 선택한 표시 이름을 받는다."""

    nickname: str
