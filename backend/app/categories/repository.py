from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.category import Category


def add_default_categories(
    db: Session, ledger_id: UUID, definitions: list[tuple[str, str]]
) -> list[Category]:
    """전달받은 정의를 해당 가계부의 기본 카테고리로 추가한다."""
    categories = [
        Category(
            ledger_id=ledger_id,
            name=name,
            description=description,
            is_default=True,
        )
        for name, description in definitions
    ]
    db.add_all(categories)
    db.flush()
    return categories

def list_categories(db: Session, ledger_id: UUID) -> list[Category]:
    """지정한 가계부의 카테고리만 조회한다."""
    statement = select(Category).where(Category.ledger_id==ledger_id).order_by(Category.name, Category.id)
    return list(db.execute(statement=statement).scalars().all())
