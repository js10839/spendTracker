from sqlalchemy import select
from sqlalchemy.engine import Connection, RowMapping

from app.db.tables import categories


def list_categories(connection: Connection) -> list[RowMapping]:
    """모든 사용자가 공유하는 운영팀 정의 카테고리를 조회한다."""
    statement = select(
        categories.c.id, categories.c.name, categories.c.icon, categories.c.is_default
    ).order_by(categories.c.name, categories.c.id)
    return list(connection.execute(statement).mappings())
