from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger
from app.transactions.schema import ManualTransactionCreate, TransactionRead
from app.transactions.service import (
    create_manual_transaction,
    list_ledger_transactions,
    update_manual_transaction,
)

router = APIRouter(prefix="/ledgers/{ledger_id}/transactions", tags=["transactions"])

@router.post("", status_code=status.HTTP_201_CREATED)
def add_manual_transaction(data: ManualTransactionCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> dict[str, str|int|None]:
    """가계부 접근 권한을 확인한 뒤 수동 지출을 생성한다."""
    transaction = create_manual_transaction(db, ledger_id=ledger.id, user_id=user_id, data=data)
    return {"id": str(transaction.id), "ledger_id": str(transaction.ledger_id), "payment_method_id": str(transaction.payment_method_id), "category_id": str(transaction.category_id), "amount_cents": transaction.amount_cents, "memo": transaction.memo, "transacted_at": transaction.transacted_at.isoformat()}

@router.get("", response_model=list[TransactionRead])
def get_ledger_transactions(start_date: date, end_date: date, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> list[TransactionRead]:
    """접근 가능한 가계부의 지정 기간 지출 목록을 반환한다."""
    transactions = list_ledger_transactions(db, ledger_id=ledger.id, start_date=start_date, end_date=end_date)
    return [TransactionRead.model_validate(transaction) for transaction in transactions]

@router.put("/{transaction_id}", response_model=TransactionRead)
def put_manual_transaction(transaction_id: UUID, data: ManualTransactionCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> TransactionRead:
    """가계부 접근 권한을 확인한 뒤 수동 지출 전체를 수정한다."""
    transaction = update_manual_transaction(db, ledger_id=ledger.id, transaction_id=transaction_id, user_id=user_id, data=data)
    return TransactionRead.model_validate(transaction)