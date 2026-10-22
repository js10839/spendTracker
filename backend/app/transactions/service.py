from datetime import date
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

def list_ledger_transactions(db: Session, ledger_id: UUID, start_date:date, end_date: date) -> list[Transaction]:
    """유효한 조회 기간인지 확인한 뒤 가계부 지출 목록을 반환한다."""
    if start_date > end_date:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="start_date must be on or before end_date")
    return repository.list_ledger_transactions(db, ledger_id=ledger_id, start_date=start_date, end_date=end_date)

def update_manual_transaction(db: Session, ledger_id: UUID, transaction_id: UUID, user_id: UUID, data:ManualTransactionCreate) -> Transaction:
    """수동 지출과 새 입력값을 검증한 뒤 변경을 확정한다."""
    transaction = repository.find_ledger_manual_transaction(db, ledger_id=ledger_id, transaction_id=transaction_id,)
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction Not Found")

    if repository.find_user_payment_method(db, payment_method_id=data.payment_method_id, user_id=user_id,) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment Method Not Found")

    if repository.find_global_category(db, category_id=data.category_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category Not Found")

    try:
        updated = repository.update_manual_transaction(db, transaction=transaction, payment_method_id=data.payment_method_id, category_id=data.category_id, amount_cents=data.amount_cents, transacted_at=data.transacted_at, memo=data.memo)
        db.commit()
        return updated
    except Exception:
        db.rollback()
        raise