from datetime import date
from typing import Literal, Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class IncomeRecordCreate(BaseModel):
    """수입 유형에 따라 필요한 입력값을 검증한다."""

    income_type: Literal["paycheck", "cashback", "other"]
    amount_cents: int = Field(gt=0)
    received_at: date
    memo: str | None = None
    from_name: str | None = Field(default=None, min_length=1)
    applied_to: UUID | None = None
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

class IncomePlanCreate(BaseModel):
    """일회성 또는 반복되는 예정 수입의 입력값을 검증한다."""

    income_type: Literal["paycheck", "cashback", "other"]
    expected_amount_cents: int = Field(gt=0)
    expected_date: date
    frequency: Literal["once", "biweekly", "monthly"] = "once"
    memo: str | None = None
    from_name: str | None = Field(default=None, min_length=1)
    applied_to: UUID | None = None

    @model_validator(mode="after")
    def validate_type_fields(self) -> Self:
        """수입 유형에 필요한 필드와 반복 가능 여부를 확인한다."""
        if self.income_type == "paycheck":
            if self.from_name is None or self.applied_to is not None:
                raise ValueError("Paycheck requires From and cannot have Applied to")
        elif self.income_type == "cashback":
            if self.from_name is not None or self.applied_to is None:
                raise ValueError("Cashback requires a registered payment method")
        elif self.from_name is not None or self.applied_to is not None:
            raise ValueError("Other accepts only amount, date, and note")

        if self.income_type != "paycheck" and self.frequency != "once":
            raise ValueError("Only Paycheck can repeat")
        return self

class IncomePlanRead(BaseModel):
    """예정 수입 규칙과 다음 미확인 입금일을 반환한다."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    ledger_id: UUID
    income_type: str
    from_name: str | None
    payment_method_id: UUID | None
    expected_amount_cents: int
    memo: str | None
    frequency: str
    reference_date: date
    next_expected_date: date
    is_active: bool
    adjusted_expected_date: date | None = None

class IncomePlanConfirm(BaseModel):
    """특정 예정일의 실제 입금일과 변경된 금액을 받는다."""

    expected_date: date
    received_at: date
    amount_cents: int | None = Field(default=None, gt=0)

class IncomeRecordUpdate(BaseModel):
    """기존 수입 유형을 유지하며 실제 입금 내용을 수정할 입력값을 받는다."""

    amount_cents: int = Field(gt=0)
    received_at: date
    memo: str | None = None
    from_name: str | None = Field(default=None, min_length=1)
    applied_to: UUID | None = None

class IncomePlanUpdate(BaseModel):
    """활성 예정 수입의 다음 일정과 입력값을 수정할 때 받는다."""

    expected_amount_cents: int = Field(gt=0)
    expected_date: date
    frequency: Literal["once", "biweekly", "monthly"]
    memo: str | None = None
    from_name: str | None = Field(default=None, min_length=1)
    applied_to: UUID | None = None

class IncomeCalendarEntryRead(BaseModel):
    """예정 또는 확정된 수입 한 회차를 달력에 표시한다."""

    status: Literal["planned", "received"]
    income_source_id: UUID | None
    income_record_id: UUID | None
    income_type: str
    from_name: str | None
    payment_method_id: UUID | None
    amount_cents: int
    expected_date: date | None
    received_at: date | None
    display_date: date
    memo: str | None