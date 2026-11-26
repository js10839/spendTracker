from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models.payment_method import PaymentMethod


def add_payment_method(db: Session, user_id: UUID, name: str, method_type: str, closing_day: int|None, color: str) -> PaymentMethod:
    """결제수단을 추가하고 생성된 ID를 사용할 수 있게 flush한다."""
    payment_method = PaymentMethod(user_id=user_id, type=method_type, closing_day=closing_day, name=name, color=color)
    db.add(payment_method)
    db.flush()
    return payment_method

def find_user_payment_method(db: Session, payment_method_id: UUID, user_id: UUID) -> PaymentMethod | None:
    """요청한 결제수단이 현재 사용자의 지갑에 있을 때만 반환한다."""
    statement = select(PaymentMethod).where(
        PaymentMethod.id == payment_method_id,
        PaymentMethod.user_id == user_id,
    )
    return db.execute(statement=statement).scalar_one_or_none()

def find_cash_payment_method(db: Session, user_id: UUID) -> PaymentMethod | None:
    """사용자 지갑에 이미 현금 결제수단이 있는지 확인한다."""
    statement = select(PaymentMethod).where(PaymentMethod.user_id==user_id, PaymentMethod.type=="cash-like", func.lower(PaymentMethod.name)=="cash").limit(1)
    return db.execute(statement).scalar_one_or_none()

def list_payment_methods(db: Session, user_id: UUID) -> list[PaymentMethod]:
    """현재 사용자에게 속한 결제수단을 가계부와 무관하게 조회한다."""
    statement = select(PaymentMethod).where(PaymentMethod.user_id==user_id).order_by(PaymentMethod.created_at, PaymentMethod.id)
    return list(db.execute(statement).scalars().all())

def update_payment_method_color(db: Session, payment_method: PaymentMethod, color: str) -> PaymentMethod:
    """서비스에서 수정 가능 여부를 확인한 결제수단의 색상을 변경한다."""
    payment_method.color = color
    db.flush()
    return payment_method
