from datetime import date
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models.transaction import Transaction
from app.db.models.transaction_item import TransactionItem
from app.transactions import repository
from app.transactions.schema import (
    ManualTransactionGroupCreate,
    TransactionGroupRead,
    TransactionGroupUpdate,
    TransactionItemRead,
)


def create_grouped_manual_transaction(db: Session, ledger_id: UUID, user_id: UUID, data: ManualTransactionGroupCreate) -> TransactionGroupRead:
    """결제수단 소유권과 품목 카테고리를 확인한 뒤 결제·품목을 함께 확정한다."""
    if repository.find_user_payment_method(db, payment_method_id=data.payment_method_id, user_id=user_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")

    for category_id in {item.category_id for item in data.items}:
        if repository.find_global_category(db, category_id=category_id) is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

    items = [(item.name, item.category_id, item.amount_cents) for item in data.items]

    try:
        transaction, transaction_items = repository.add_grouped_manual_transaction(db, ledger_id=ledger_id, payment_method_id=data.payment_method_id, merchant=data.merchant, transacted_at=data.transacted_at, memo=data.memo, tax_cents=data.tax_cents, tip_cents=data.tip_cents, items=items)
        result = build_transaction_group_read(transaction=transaction, items=transaction_items)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise

def build_transaction_group_read(transaction: Transaction, items: list[TransactionItem]) -> TransactionGroupRead:
    """결제와 품목을 합쳐 계산된 총액이 포함된 응답을 만든다."""
    return TransactionGroupRead(id=transaction.id, ledger_id=transaction.ledger_id, payment_method_id=transaction.payment_method_id, merchant=transaction.merchant, transacted_at=transaction.transacted_at, memo=transaction.memo, source=transaction.source, tax_cents=transaction.tax_cents, tip_cents=transaction.tip_cents, total_cents=sum(item.amount_cents for item in items) + transaction.tax_cents + transaction.tip_cents, items=[TransactionItemRead.model_validate(item) for item in items])

def list_ledger_transactions(db: Session, ledger_id: UUID, start_date:date, end_date: date) -> list[TransactionGroupRead]:
    """기간 내 결제와 품목을 조회해 계산된 총액이 포함된 목록을 만든다."""
    if start_date > end_date:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="start_date must be on or before end_date")

    transactions = repository.list_ledger_transactions(db, ledger_id=ledger_id, start_date=start_date, end_date=end_date)
    items_by_transaction: dict[UUID, list[TransactionItem]] = {transaction.id: [] for transaction in transactions}

    if transactions:
        items = repository.list_transaction_items(db, [transaction.id for transaction in transactions])
        for item in items:
            items_by_transaction[item.transaction_id].append(item)

    return [build_transaction_group_read(transaction=transaction, items=items_by_transaction[transaction.id]) for transaction in transactions]

def update_transaction_group(db: Session, ledger_id: UUID, transaction_id: UUID, user_id: UUID, data: TransactionGroupUpdate) -> TransactionGroupRead:
    """거래 소유 범위와 기존 품목 ID를 검증한 뒤 값을 수정한다."""
    transaction = repository.find_ledger_transaction(db, ledger_id=ledger_id, transaction_id=transaction_id)
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    if repository.find_user_payment_method(db, payment_method_id=data.payment_method_id, user_id=user_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")

    existing_items = repository.list_transaction_items(db, [transaction_id])
    existing_by_id = {item.id: item for item in existing_items}
    requested_ids = [item.id for item in data.items]

    if len(requested_ids) != len(set(requested_ids)) or set(requested_ids) != set(existing_by_id):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Items must match the existing transaction items")

    for category_id in {item.category_id for item in data.items}:
        if repository.find_global_category(db, category_id=category_id) is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

    item_updates = [(existing_by_id[item.id], item.name, item.category_id, item.amount_cents) for item in data.items]

    try:
        repository.apply_transaction_update(db, transaction=transaction, payment_method_id=data.payment_method_id, merchant=data.merchant, transacted_at=data.transacted_at, memo=data.memo, tax_cents=data.tax_cents, tip_cents=data.tip_cents, item_updates=item_updates)
        result = build_transaction_group_read(transaction=transaction, items=existing_items)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
