from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

# Engine은 연결 풀을 관리하고, SessionLocal은 요청별 Session을 만든다.
engine = create_engine(settings.db_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    """요청 처리 동안 사용할 Session을 제공하고 끝나면 닫는다."""
    with SessionLocal() as session:
        yield session
