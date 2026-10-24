from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Transaction(Base):
    """직접 입력하거나 영수증에서 확정한 지출을 cents 단위로 기록한다."""

    __tablename__ = "transactions"
    __table_args__ = (
        CheckConstraint(
            "source IN ('manual', 'receipt_parse')",
            name="ck_transactions_source",
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    ledger_id: Mapped[UUID] = mapped_column(ForeignKey("ledgers.id"), nullable=False)
    payment_method_id: Mapped[UUID] = mapped_column(
        ForeignKey("payment_methods.id"), nullable=False
    )
    currency: Mapped[str] = mapped_column(Text, nullable=False, server_default="USD")
    merchant: Mapped[str | None] = mapped_column(Text)
    memo: Mapped[str | None] = mapped_column(Text)
    transacted_at: Mapped[date] = mapped_column(Date, nullable=False)
    source: Mapped[str] = mapped_column(Text, nullable=False, server_default="manual")
    tax_cents: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    tip_cents: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
