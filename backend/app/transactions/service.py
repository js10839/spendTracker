from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models.transaction import Transaction
from app.transactions import repository
from app.transactions.schema import ManualTransactionCreate


def create_manual_transaction(db:Session, ledger_id: UUID, user_id: UUID, data: ManualTransactionCreate) -> Transaction:
    """결제수단 소유권과 카테고리를 확인한 뒤 수동 지출을 저장한다."""
    if repository.find_user_payment_method(db, payment_method_id=data.payment_method_id, user_id=user_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")

    if repository.find_global_category(db, category_id=data.category_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

    try:
        transaction = repository.add_manual_transaction(db, ledger_id=ledger_id, payment_method_id=data.payment_method_id, category_id=data.category_id, amount_cents=data.amount_cents, memo=data.memo, transacted_at=data.transacted_at)
        db.commit()
        return transaction
    except Exception:
        db.rollback()
        raise