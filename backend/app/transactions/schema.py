from datetime import date
from uuid import UUID

from pydantic import BaseModel, Field


class ManualTransactionCreate(BaseModel):
    """사용자가 직접 입력하는 지출의 요청값이다."""
    payment_method_id: UUID
    category_id: UUID
    amount_cents: int = Field(gt=0)
    transacted_at: date
    memo: str | None = None