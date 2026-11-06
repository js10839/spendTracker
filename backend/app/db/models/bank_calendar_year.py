from datetime import datetime

from sqlalchemy import JSON, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BankCalendarYear(Base):
    """Bankday에서 받은 us-fed 연간 휴일 목록과 마지막 갱신 시각을 보관한다."""

    __tablename__ = "bank_calendar_years"

    year: Mapped[int] = mapped_column(Integer, primary_key=True)
    holidays: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
