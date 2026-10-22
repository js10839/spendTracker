from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger
from app.transactions.schema import ManualTransactionCreate
from app.transactions.service import create_manual_transaction

router = APIRouter(prefix="/ledgers/{ledger_id}/transactions", tags=["transactions"])

@router.post("", status_code=status.HTTP_201_CREATED)
def add_manual_transaction(data: ManualTransactionCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> dict[str, str|int|None]:
    """가계부 접근 권한을 확인한 뒤 수동 지출을 생성한다."""
    transaction = create_manual_transaction(db, ledger_id=ledger.id, user_id=user_id, data=data)
    return {"id": str(transaction.id), "ledger_id": str(transaction.ledger_id), "payment_method_id": str(transaction.payment_method_id), "category_id": str(transaction.category_id), "amount_cents": transaction.amount_cents, "memo": transaction.memo, "transacted_at": transaction.transacted_at.isoformat()}