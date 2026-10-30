from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.auth.token import verify_access_token
from app.db.session import get_db
from app.users.service import ensure_user_not_deleting

bearer_scheme = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> UUID:
    """Bearer 토큰을 검증해 Supabase Auth가 발급한 사용자 UUID를 얻는다."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return verify_access_token(credentials.credentials)

def get_active_user_id(request: Request, user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> UUID:
    """토큰과 삭제 진행 상태를 확인한 사용자 ID를 반환한다."""
    ensure_user_not_deleting(db, user_id=user_id, for_write=request.method not in {"GET", "HEAD", "OPTIONS"})
    return user_id
