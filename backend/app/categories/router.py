from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.categories.service import list_global_categories
from app.db.session import get_db

router = APIRouter(prefix="/categories", tags=["categories"])

@router.get("")
def get_categories(user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> list[dict[str, str|bool|None]]:
    """인증된 사용자에게 공통 카테고리 목록을 반환한다."""
    categories = list_global_categories(db)
    return [{"id": str(category.id), "name": category.name, "icon": category.icon, "is_default": category.is_default} for category in categories]
