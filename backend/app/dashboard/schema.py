"""Chart-ready dashboard responses. All money is integer cents."""

from datetime import date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class SpendingPeriod(BaseModel):
    start_date: date
    end_date: date
    total_cents: int


class CategoryTotal(BaseModel):
    # NULL identifies the remainder not assigned to a receipt-item category.
    category_id: UUID | None
    name: str
    amount_cents: int


class CardStatement(SpendingPeriod):
    payment_method_id: UUID
    name: str
    color: str
    spent_through: date
    top_categories: list[CategoryTotal]


class PaydaySource(BaseModel):
    income_source_id: UUID
    from_name: str | None
    expected_date: date
    amount_cents: int


class NextPayday(BaseModel):
    date: date
    days_remaining: int
    amount_cents: int
    sources: list[PaydaySource]


class SpendingBucket(BaseModel):
    date: date
    total_cents: int


class SpendingChart(BaseModel):
    start_date: date
    end_date: date
    buckets: list[SpendingBucket]


class CyclePace(BaseModel):
    mode: Literal["all", "card"]
    payment_method_id: UUID | None
    name: str
    color: str | None
    elapsed_days: int
    previous_elapsed_days: int
    current: SpendingPeriod
    previous: SpendingPeriod
    current_cycle_end: date
    previous_cycle_end: date


class CategoryBreakdown(SpendingPeriod):
    categories: list[CategoryTotal]


class DashboardRead(BaseModel):
    as_of: date
    currency: Literal["USD"]
    payment_method_id: UUID | None
    spending_30_days: SpendingPeriod
    card_statements: list[CardStatement]
    next_payday: NextPayday | None
    monthly_spending: SpendingChart
    yearly_spending: SpendingChart
    cycle_pace: list[CyclePace]
    category_breakdown: CategoryBreakdown
