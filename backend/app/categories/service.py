from sqlalchemy.orm import Session

from app.categories import repository
from app.db.models.category import Category


def list_global_categories(db: Session) -> list[Category]:
    """운영팀이 관리하는 공통 카테고리 목록을 반환한다."""
    return repository.list_categories(db)
