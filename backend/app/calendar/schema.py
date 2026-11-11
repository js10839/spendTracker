from datetime import date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel

from app.day_notes.schema import DayNoteRead
from app.income.schema import IncomeCalendarEntryRead
from app.transactions.schema import TransactionGroupRead


class CalendarPaymentMethodRead(BaseModel):
    id: UUID
    name: str
    type: Literal["credit", "cash-like"]
    color: str
    closing_day: int | None


class CalendarDotRead(BaseModel):
    payment_method_id: UUID
    label: str
    color: str | None
    transaction_count: int


class CalendarDayRead(BaseModel):
    date: date
    transactions: list[TransactionGroupRead]
    dots: list[CalendarDotRead]
    income: list[IncomeCalendarEntryRead]
    closing_cards: list[CalendarPaymentMethodRead]
    note: DayNoteRead | None
    spending_cents: int
    received_income_cents: int


class CalendarRead(BaseModel):
    mode: Literal["all", "card"]
    payment_method_id: UUID | None
    start_date: date
    end_date: date
    previous_anchor_date: date
    next_anchor_date: date
    payment_methods: list[CalendarPaymentMethodRead]
    cards: list[CalendarPaymentMethodRead]
    days: list[CalendarDayRead]
