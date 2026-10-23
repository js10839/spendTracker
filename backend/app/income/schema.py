from datetime import date
from typing import Literal, Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class IncomeRecordCreate(BaseModel):
    """수입 유형에 따라 필요한 입력값을 검증한다."""

    income_type: Literal["paycheck", "cashback", "refund", "other"]
    amount_cents: int = Field(gt=0)
    received_at: date
    memo: str | None = None
    from_name: str | None = Field(default=None, min_length=1)
    applied_to: UUID | Literal["other"] | None = None
    frequency: Literal["never", "biweekly", "monthly"] = "never"

    @model_validator(mode="after")
    def validate_type_fields(self) -> Self:
        """유형마다 화면에서 제공하는 필드만 받는다."""
        if self.income_type == "paycheck":
            if self.from_name is None or self.applied_to is not None:
                raise ValueError("Paycheck requires From and cannot have Applied to")
        elif self.income_type == "cashback":
            if self.from_name is not None or not isinstance(self.applied_to, UUID):
                raise ValueError("Cashback requires a registered payment method")
        elif self.income_type == "refund":
            if self.from_name is None or self.applied_to is None:
                raise ValueError("Refund requires From and Applied to")
        else:
            if self.from_name is not None or self.applied_to is not None:
                raise ValueError("Other accepts only amount, date, and note")

        if self.income_type != "paycheck" and self.frequency != "never":
            raise ValueError("Only Paycheck can repeat")
        return self

class IncomeRecordRead(BaseModel):
    """저장된 실제 수입을 API 응답으로 전달한다."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    ledger_id: UUID
    income_source_id: UUID | None
    payment_method_id: UUID | None
    income_type: str
    from_name: str | None
    amount_cents: int
    received_at: date
    memo: str | None