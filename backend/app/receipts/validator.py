# 금액 및 데이터 검증

from decimal import Decimal
from pydantic import BaseModel
from .schemas import ReceiptData

CENT = Decimal("0.01")

class ValidationReport(BaseModel):
    status: str
    calculated_total: Decimal
    receipt_total: Decimal | None
    difference: Decimal | None
    item_count: int
    issues: list[str]

def validate_receipt(data: ReceiptData) -> ValidationReport:
    issues = []
    if not data.items:
        issues.append("No items extracted")
    for i, item in enumerate(data.items):
        if item.price != item.price.quantize(CENT):
            issues.append(f"Item {i} has sub-cent precision")
    for field in ("tax", "tip", "total"):
        value = getattr(data, field)
        if value is not None and value != value.quantize(CENT):
            issues.append(f"{field} has sub-cent precision")
    calculated = sum((item.price for item in data.items), Decimal("0")) + data.tax + data.tip
    calculated = calculated.quantize(CENT)
    difference = None if data.total is None else (calculated - data.total).quantize(CENT)
    if data.total is None:
        issues.append("Receipt total unreadable")
    elif difference != 0:
        issues.append("Total mismatch")
    return ValidationReport(status="pass" if not issues else "review", calculated_total=calculated, receipt_total=data.total, difference=difference, item_count=len(data.items), issues=issues)
