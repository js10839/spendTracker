from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger
from app.payment_methods.schema import PaymentMethodCreate
from app.payment_methods.service import create_payment_method

router = APIRouter(prefix="/ledgers/{ledger_id}/payment_methods", tags=["payment-methods"])

@router.post("", status_code=status.HTTP_201_CREATED)
def add_payment_method_to_ledger(data: PaymentMethodCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> dict[str,str | int | None]:
    """접근 권한이 확인된 가계부에 결제수단을 추가한다."""
    payment_method = create_payment_method(db, ledger_id=ledger.id, data=data)
    return {"id": str(payment_method.id), "name": payment_method.name, "type": payment_method.type, "closing_day": payment_method.closing_day, "color": payment_method.color}
