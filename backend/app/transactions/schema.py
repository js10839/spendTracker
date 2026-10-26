from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TransactionItemCreate(BaseModel):
    """수동 결제에 포함할 품목 한 개의 입력값이다."""
    name: str = Field(min_length=1)
    category_id: UUID
    amount_cents: int

class ManualTransactionGroupCreate(BaseModel):
    """품목 최소 한 개를 받아 총액을 계산할 수 있게 한다."""
    model_config = ConfigDict(extra="forbid")

    payment_method_id: UUID
    merchant: str | None = None
    transacted_at: date
    memo: str | None = None
    tax_cents: int = Field(default=0, ge=0)
    tip_cents: int = Field(default=0, ge=0)
    items: list[TransactionItemCreate] = Field(min_length=1)

class TransactionItemRead(BaseModel):
    """저장된 품목 한 개를 반환한다."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    category_id: UUID
    amount_cents: int

class TransactionGroupRead(BaseModel):
    """결제 한 건과 품목·계산된 합계를 함께 반환한다."""

    id: UUID
    ledger_id: UUID
    payment_method_id: UUID
    merchant: str | None
    transacted_at: date
    memo: str | None
    source: str
    total_cents: int
    tax_cents: int
    tip_cents: int
    items: list[TransactionItemRead]

class TransactionItemUpdate(BaseModel):
    """기존 품목은 ID로 수정하고 ID가 없는 품목은 새로 추가한다."""
    id: UUID | None = None
    name: str = Field(min_length=1)
    category_id: UUID
    amount_cents: int

class TransactionGroupUpdate(BaseModel):
    """기존 ID를 유지할 최종 품목 목록으로 총액을 다시 계산한다."""
    model_config = ConfigDict(extra="forbid")

    payment_method_id: UUID
    merchant: str | None = None
    transacted_at: date
    memo: str | None = None
    tax_cents: int = Field(ge=0)
    tip_cents: int = Field(ge=0)
    items: list[TransactionItemUpdate] = Field(min_length=1)
