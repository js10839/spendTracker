from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.categories.service import list_ledger_categories
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger

router = APIRouter(prefix="/ledgers/{ledger_id}/categories", tags=["categories"])

@router.get("")
def get_categories(ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> list[dict[str, str|bool|None]]:
    """접근 가능한 가계부의 카테고리 목록을 반환한다."""
    categories = list_ledger_categories(db, ledger_id=ledger.id)
    return [{"id": str(category.id), "name": category.name, "icon": category.icon, "is_default": category.is_default} for category in categories]
