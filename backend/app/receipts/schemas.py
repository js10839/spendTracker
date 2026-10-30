# API Output Format
# JSON 데이터 구조

from datetime import date as Date
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, WithJsonSchema

# Keep Decimal validation locally without exposing its generated regex to the API.
Money = Annotated[
    Decimal,
    WithJsonSchema({"type": "string", "description": "Decimal amount, e.g. 2.50 or -0.55"}, mode="validation"),
]

Category = Literal["Food", "Living", "Electronics", "Fashion", "Dining", "Transport", "Subscription", "Utilities & Bills", "Health", "Entertainment", "Travel", "Refund", "Coffee", "Etc"]

class ReceiptItem(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(
        min_length=1,
        description=(
            "Product or adjustment name, including returns, refunds, discounts, and coupons. "
            "Preserve labels identifying these adjustments. "
            "Normalize abbreviations only when confident."
        ),
    )
    price: Money = Field(
        description=(
            "Signed line amount, not unit price. Purchases are positive; returns, refunds, "
            "discounts, and coupons that reduce the total are negative. "
            "Interpret a trailing minus, parentheses, or an explicit return/refund label "
            "as negative when the receipt clearly indicates a deduction. "
            "Use the monetary discount amount, not a percentage. "
            "Do not deduct an adjustment again if it is already included in the line amount."
        ),
    )
    category: Category = Field(
        default = "Etc",
        description=(
            "If price is negative, assign Refund, including returns, refunds, discounts, "
            "and coupons. Otherwise, assign based on what was purchased, not the merchant; "
            "do not use Refund for zero or positive prices. "
            "If no category fits or the category is uncertain, assign Etc. "
        ),
    )

class ReceiptData(BaseModel):
    model_config = ConfigDict(extra="forbid")
    merchant: str | None = Field(
        description="Store or business name printed on the receipt; null if unknown or unreadable.",
    )
    location: str | None = Field(
        default=None,
        description=(
            "Store address or location printed on the receipt, including street, city, "
            "state, and postal code when available. Do not infer missing address details "
            "or use customer addresses. Return null if unreadable or absent."
        ),
    )
    date: Date | None = Field(
        description=(
            "Purchase date in ISO YYYY-MM-DD format; null if unknown or unreadable. "
            "US receipts use month/day/year: 10/01/26 means 2026-10-01. "
            "Expand two-digit purchase years as 20YY."
        ),
    )
    currency: Literal["USD"] = Field(
        description="Receipt currency. Only USD is supported; never convert or relabel another currency as USD.",
    )
    items: list[ReceiptItem] = Field(
        description=(
            "Individual purchase, return, and refund lines, including separate coupon "
            "and discount adjustments. Do not duplicate adjustments already included "
            "in item line amounts. "
            "Omit unreadable item lines. Exclude subtotal, tax, tip, and total."
        ),
    )
    tax: Money = Field(description="Receipt tax amount. Use 0 if absent.")
    tip: Money = Field(description="Receipt tip amount. Use 0 if absent.")
    total: Money | None = Field(
        description=(
            "Final receipt total including tax and tip, after returns, refunds, discounts, "
            "and coupons. Preserve a net refund as a negative total. "
            "Return null if unknown or unreadable."
        ),
    )
