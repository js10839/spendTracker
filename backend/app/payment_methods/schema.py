from typing import Annotated, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator


class PaymentMethodCreate(BaseModel):
    """사용자에 추가할 결제수단의 입력값이다."""
    name: str = Field(min_length=1)
    type: Literal["credit", "cash-like"]
    closing_day: int|None = Field(default=None, ge=1, le=31)
    color: str

    @model_validator(mode="after")
    def validate_closing_day(self) -> Self:
        """신용카드 마감일을 검증하고 기본 Cash의 중복 등록을 막는다."""
        if self.type == "credit" and self.closing_day is None:
            raise ValueError("Credit Cards require a closing day")
        if self.type == "cash-like" and self.closing_day is not None:
            raise ValueError("Cash-like methods cannot have a closing day")
        if self.type == "cash-like" and self.name.strip().casefold() == "cash":
            raise ValueError("Cash is already built in")
        return self

class PaymentMethodUpdate(BaseModel):
    """내 지갑에서 이름·마감일·색상 중 보낸 필드만 받는다."""
    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)] | None = None
    closing_day: int | None = Field(default=None, ge=1, le=31, strict=True)
    color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")

    @model_validator(mode="after")
    def validate_update(self) -> Self:
        """빈 수정 요청과 이름·색상을 명시적으로 지우는 요청을 막는다."""
        if not self.model_fields_set:
            raise ValueError("Provide a name, closing day, or color")
        if "name" in self.model_fields_set and self.name is None:
            raise ValueError("Name cannot be null")
        if "color" in self.model_fields_set and self.color is None:
            raise ValueError("Color cannot be null")
        return self
