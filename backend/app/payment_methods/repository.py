from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models.payment_method import PaymentMethod


def add_payment_method(db: Session, ledger_id: UUID, name: str, method_type: str, closing_day: int|None, color: str) -> PaymentMethod:
    """결제수단을 추가하고 생성된 ID를 사용할 수 있게 flush한다."""
    payment_method = PaymentMethod(ledger_id=ledger_id, type=method_type, closing_day=closing_day, name=name, color=color)
    db.add(payment_method)
    db.flush()
    return payment_method