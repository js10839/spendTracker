# API Output Format
# JSON 데이터 구조

from decimal import Decimal
from datetime import date
from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, WithJsonSchema

# Keep Decimal validation locally without exposing its generated regex to the API.
Money = Annotated[
    Decimal,
    WithJsonSchema({"type": "string", "description": "Decimal amount, e.g. 2.50 or -0.55"}, mode="validation"),
]

Category = Literal["Food", "Living", "Electronics", "Fashion", "Dining", "Transport", "Subscription", "Utilities & Bills", "Health", "Entertainment", "Travel", "Etc"]

class ReceiptItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1)
    price: Money
    category: Category

class ReceiptData(BaseModel):
    model_config = ConfigDict(extra="forbid")
    merchant: str | None
    date: date | None
    currency: Literal["USD"]
    items: list[ReceiptItem]
    tax: Money
    tip: Money
    total: Money | None
