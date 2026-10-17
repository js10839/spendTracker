from uuid import UUID

from sqlalchemy.orm import Session

from app.categories import repository
from app.db.models.category import Category


def list_ledger_categories(db: Session, ledger_id: UUID) -> list[Category]:
    """가계부의 카테고리 목록을 조회한다."""
    return repository.list_categories(db, ledger_id=ledger_id)
