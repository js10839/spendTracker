from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.payment_method import PaymentMethod


def add_payment_method(db: Session, user_id: UUID, name: str, method_type: str, closing_day: int|None, color: str) -> PaymentMethod:
    """결제수단을 추가하고 생성된 ID를 사용할 수 있게 flush한다."""
    payment_method = PaymentMethod(user_id=user_id, type=method_type, closing_day=closing_day, name=name, color=color)
    db.add(payment_method)
    db.flush()
    return payment_method

def list_payment_methods(db: Session, user_id: UUID) -> list[PaymentMethod]:
    """현재 사용자에게 속한 결제수단을 가계부와 무관하게 조회한다."""
    statement = select(PaymentMethod).where(PaymentMethod.user_id==user_id).order_by(PaymentMethod.created_at, PaymentMethod.id)
    return list(db.execute(statement).scalars().all())
