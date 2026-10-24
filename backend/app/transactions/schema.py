from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TransactionItemCreate(BaseModel):
    """수동 결제에 포함할 품목 한 개의 입력값이다."""
    name: str = Field(min_length=1)
    category_id: UUID
    amount_cents: int = Field(gt=0)

class ManualTransactionGroupCreate(BaseModel):
    """품목 여러 개와 결제 전체 Tax·Tip을 받는 수동 입력값이다."""
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
    tax_cents: int
    tip_cents: int
    total_cents: int
    items: list[TransactionItemRead]

class TransactionItemUpdate(BaseModel):
    """기존 품목 ID를 유지하면서 수정할 값을 받는다."""
    id: UUID
    name: str = Field(min_length=1)
    category_id: UUID
    amount_cents: int = Field(gt=0)

class TransactionGroupUpdate(BaseModel):
    """결제 헤더와 기존 품목 전체의 수정값을 받는다."""
    payment_method_id: UUID
    merchant: str | None = None
    transacted_at: date
    memo: str | None = None
    tax_cents: int = Field(ge=0)
    tip_cents: int = Field(ge=0)
    items: list[TransactionItemUpdate] = Field(min_length=1)