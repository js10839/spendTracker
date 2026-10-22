from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ManualTransactionCreate(BaseModel):
    """사용자가 직접 입력하는 지출의 요청값이다."""
    payment_method_id: UUID
    category_id: UUID
    amount_cents: int = Field(gt=0)
    transacted_at: date
    memo: str | None = None

class TransactionRead(BaseModel):
    """저장된 지출을 API 응답으로 전달한다."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    ledger_id: UUID
    payment_method_id: UUID
    category_id: UUID
    amount_cents: int
    transacted_at: date
    memo: str | None