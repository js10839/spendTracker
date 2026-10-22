from typing import Literal, Self

from pydantic import BaseModel, Field, model_validator


class PaymentMethodCreate(BaseModel):
    """사용자에 추가할 결제수단의 입력값이다."""
    name: str = Field(min_length=1)
    type: Literal["credit", "cash-like"]
    closing_day: int|None = Field(default=None, ge=1, le=31)
    color: str

    @model_validator(mode="after")
    def validate_closing_day(self) -> Self:
        """신용카드에만 1~31일의 명세서 마감일을 허용한다."""
        if self.type == "credit" and self.closing_day is None:
            raise ValueError("Credit Cards require a closing day")
        if self.type == "cash-like" and self.closing_day is not None:
            raise ValueError("Cash-like methods cannot have a closing day")
        return self