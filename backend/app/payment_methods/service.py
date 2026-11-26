from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.db.models.payment_method import PaymentMethod
from app.payment_methods import repository
from app.payment_methods.schema import PaymentMethodCreate


def create_payment_method(db: Session, user_id: UUID, data: PaymentMethodCreate) -> PaymentMethod:
    """검증된 결제수단을 저장하고 트랜잭션을 확정한다."""
    try:
        payment_method = repository.add_payment_method(db, user_id=user_id, name=data.name, method_type=data.type, closing_day=data.closing_day, color=data.color)
        db.commit()
        return payment_method
    except Exception:
        db.rollback()
        raise


def get_payment_methods(db: Session, user_id: UUID) -> list[PaymentMethod]:
    """사용자의 지갑 목록을 조회한다."""
    return repository.list_payment_methods(db, user_id)

def update_payment_method_color(db: Session, user_id: UUID, payment_method_id: UUID, color: str) -> PaymentMethod:
    """본인 지갑의 결제수단 색상을 변경하고 기본 Cash의 고정 색상을 보호한다."""
    try:
        method = repository.find_user_payment_method(db, payment_method_id=payment_method_id, user_id=user_id)
        if method is None:
            raise HTTPException(status_code=404, detail="Payment method not found")

        if method.type == "cash-like" and method.name.strip().casefold() == "cash":
            raise HTTPException(status_code=422, detail="The default Cash color cannot be changed")

        updated = repository.update_payment_method_color(db, payment_method=method, color=color)
        db.commit()
        return updated
    except Exception:
        db.rollback()
        raise