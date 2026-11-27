from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.db.models.payment_method import PaymentMethod
from app.payment_methods import repository
from app.payment_methods.schema import PaymentMethodCreate, PaymentMethodUpdate


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

def update_payment_method_details(db: Session, user_id: UUID, payment_method_id: UUID, data: PaymentMethodUpdate) -> PaymentMethod:
    """본인 결제수단의 이름·마감일·색상을 검증한 뒤 한 번에 저장한다."""
    try:
        method = repository.find_user_payment_method(db, payment_method_id=payment_method_id, user_id=user_id)
        if method is None:
            raise HTTPException(status_code=404, detail="Payment method not found")

        # 이름만 수정할 때는 기존 마감일을 기준으로 검증한다.
        update_closing_day = "closing_day" in data.model_fields_set
        closing_day = data.closing_day if update_closing_day else method.closing_day

        if method.type == "credit" and closing_day is None:
            raise HTTPException(status_code=422, detail="Credit cards require a closing day")
        if method.type == "cash-like" and closing_day is not None:
            raise HTTPException(status_code=422, detail="Cash-like methods cannot have a closing day")

        # Bootstrap이 이름으로 기본 Cash를 찾으므로 현금성 수단에서 이 이름을 보호한다.
        if method.type == "cash-like":
            if method.name.strip().casefold() == "cash":
                if data.color is not None:
                    raise HTTPException(status_code=422, detail="The default Cash color cannot be changed")
                if data.name is not None and data.name != method.name:
                    raise HTTPException(status_code=422, detail="The default Cash cannot be renamed")
            elif data.name is not None and data.name.casefold() == "cash":
                raise HTTPException(status_code=422, detail="Cash is reserved for the default payment method")

        updated = repository.update_payment_method_details(
            db, method, name=data.name, closing_day=closing_day, update_closing_day=update_closing_day, color=data.color
        )
        db.commit()
        return updated
    except Exception:
        db.rollback()
        raise
