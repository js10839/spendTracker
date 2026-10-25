from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class IncomeSource(Base):
    """일회성 또는 반복되는 예정 수입을 저장한다."""

    __tablename__ = "income_sources"
    __table_args__ = (CheckConstraint("expected_amount_cents > 0", name="ck_income_sources_positive_amount"),)

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    ledger_id: Mapped[UUID] = mapped_column(ForeignKey("ledgers.id"), nullable=False)
    income_type: Mapped[str] = mapped_column(Text, nullable=False, server_default="paycheck")
    from_name: Mapped[str | None] = mapped_column(Text)
    payment_method_id: Mapped[UUID | None] = mapped_column(ForeignKey("payment_methods.id"))
    expected_amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    memo: Mapped[str | None] = mapped_column(Text)
    frequency: Mapped[str] = mapped_column(Text, nullable=False)
    reference_date: Mapped[date] = mapped_column(Date, nullable=False)
    next_expected_date: Mapped[date] = mapped_column(Date, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
