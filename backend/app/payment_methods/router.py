from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_active_user_id
from app.db.session import get_db
from app.payment_methods.schema import PaymentMethodCreate
from app.payment_methods.service import create_payment_method, get_payment_methods

router = APIRouter(prefix="/users/me/payment-methods", tags=["payment-methods"])

@router.post("", status_code=status.HTTP_201_CREATED)
def add_payment_method_to_wallet(data: PaymentMethodCreate, user_id: Annotated[UUID, Depends(get_active_user_id)], db: Annotated[Session, Depends(get_db)]) -> dict[str,str | int | None]:
    """인증된 사용자의 지갑에 결제수단을 추가한다."""
    payment_method = create_payment_method(db, user_id=user_id, data=data)
    return {"id": str(payment_method.id), "name": payment_method.name, "type": payment_method.type, "closing_day": payment_method.closing_day, "color": payment_method.color}


@router.get("")
def list_wallet_payment_methods(user_id: Annotated[UUID, Depends(get_active_user_id)], db: Annotated[Session, Depends(get_db)]) -> list[dict[str,str | int | None]]:
    """현재 사용자의 결제수단을 가계부 선택과 무관하게 반환한다."""
    payment_methods = get_payment_methods(db, user_id)
    return [{"id": str(method.id), "name": method.name, "type": method.type, "closing_day": method.closing_day, "color": method.color} for method in payment_methods]
