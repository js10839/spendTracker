from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class LedgerMember(Base):
    """사용자와 가계부의 소속 관계 및 역할을 기록한다."""

    __tablename__ = "ledger_members"

    # 두 UUID의 조합이 기본 키이며 별도 멤버십 UUID는 만들지 않는다.
    ledger_id: Mapped[UUID] = mapped_column(ForeignKey("ledgers.id"), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("users.id"), primary_key=True)
    role: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
