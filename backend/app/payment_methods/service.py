from uuid import UUID

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
