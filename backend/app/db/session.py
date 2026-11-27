from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.engine import Connection

from app.core.config import settings

engine = create_engine(settings.db_url, pool_pre_ping=True)


def get_db() -> Iterator[Connection]:
    """Share one Core connection across the request and its dependencies."""
    with engine.connect() as connection:
        yield connection
