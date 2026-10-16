from uuid import UUID

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
