from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.category import Category


def list_categories(db: Session) -> list[Category]:
    """모든 사용자가 공유하는 운영팀 정의 카테고리를 조회한다."""
    statement = select(Category).order_by(Category.name, Category.id)
    return list(db.execute(statement=statement).scalars().all())
