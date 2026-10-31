# 금액 및 데이터 검증

from decimal import Decimal

from pydantic import BaseModel

from .schemas import ReceiptData

# USD의 최소 금액 단위
CENT = Decimal("0.01")

class ValidationReport(BaseModel):
    status: str  # 문제 없으면 pass, 검토가 필요하면 review
    calculated_total: Decimal  # 항목 금액 합계 + 세금 + 팁
    receipt_total: Decimal | None  # 영수증에서 추출한 총액
    difference: Decimal | None  # calculated_total - receipt_total
    item_count: int  # 항목 수
    issues: list[str]

# Parsing한 데이터의 금액을 검사한다
def validate_receipt(data: ReceiptData) -> ValidationReport:
    issues = []

    # 구매한 item 항목이 하나도 없는 경우
    if not data.items:
        issues.append("No items extracted")

    # 원래 금액과 소수 둘째자리 값까지 반올림한 금액 비교
    # 예: 1.234는 문제지만, 값이 같은 1.230과 1.23은 허용한다.
    for i, item in enumerate(data.items):
        if item.price != item.price.quantize(CENT):
            issues.append(f"Item {i} has sub-cent precision")
    # 세금·팁·총액에도 같은 검사를 적용한다.
    for field in ("tax", "tip", "total"):
        value = getattr(data, field)
        if value is not None and value != value.quantize(CENT):
            issues.append(f"{field} has sub-cent precision")

    # 음수인 환불·할인 항목도 그대로 합산한다. 소수 둘째자리까지 계산
    calculated = sum((item.price for item in data.items), Decimal(0)) + data.tax + data.tip
    calculated = calculated.quantize(CENT)

    # 총액을 읽었을 때만 차이를 계산한다. 양수면 계산값이 더 크고, 음수면 더 작다.
    difference = None if data.total is None else (calculated - data.total).quantize(CENT)
    if data.total is None:
        issues.append("Receipt total unreadable")
    elif difference != 0:
        issues.append("Total mismatch")
        
    # 금액 일치 여부뿐 아니라 위에서 수집한 모든 문제를 기준으로 상태를 정한다.
    return ValidationReport(status="pass" if not issues else "review", calculated_total=calculated, receipt_total=data.total, difference=difference, item_count=len(data.items), issues=issues)
