from sqlalchemy.engine import Connection, RowMapping

from app.categories import repository


def list_global_categories(connection: Connection) -> list[RowMapping]:
    """운영팀이 관리하는 공통 카테고리 목록을 반환한다."""
    return repository.list_categories(connection)
