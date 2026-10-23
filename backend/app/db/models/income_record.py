from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class IncomeRecord(Base):
    """실제 수입과 카드에 적용되는 Cashback·Refund를 기록한다."""

    __tablename__ = "income_records"
    __table_args__ = (CheckConstraint("amount_cents>0", name="ck_income_records_positive_amount"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    ledger_id: Mapped[UUID] = mapped_column(ForeignKey("ledgers.id"), nullable=False)
    income_source_id: Mapped[UUID | None] = mapped_column(ForeignKey("income_sources.id"), nullable=True)
    payment_method_id: Mapped[UUID | None] = mapped_column(ForeignKey("payment_methods.id"), nullable=True)
    income_type: Mapped[str] = mapped_column(Text, nullable=False)
    from_name: Mapped[str | None] = mapped_column(Text)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    received_at: Mapped[date] = mapped_column(Date, nullable=False)
    memo: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

