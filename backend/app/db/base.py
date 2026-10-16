from sqlalchemy.orm import DeclarativeBase


# 모든 앱 SQLAlchemy 모델이 공유하는 선언형 베이스.
class Base(DeclarativeBase):
    pass
