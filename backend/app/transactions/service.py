from datetime import UTC, date, datetime, timedelta
from time import sleep
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


def normalize_item_amount(category_name: str, amount_cents: int) -> int:
    """Refund 품목은 받은 금액의 부호와 관계없이 지출에서 차감한다."""
    return -abs(amount_cents) if category_name == "Refund" else amount_cents


def create_grouped_manual_transaction(db: Session, ledger_id: UUID, user_id: UUID, data: ManualTransactionGroupCreate) -> TransactionGroupRead:
    """결제수단과 품목을 검증하고 품목·Tax·Tip의 합계를 저장한다."""
    if not data.items:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Transactions require at least one item")

    if repository.find_user_payment_method(db, payment_method_id=data.payment_method_id, user_id=user_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")

    categories = {}
    for category_id in {item.category_id for item in data.items}:
        category = repository.find_global_category(db, category_id=category_id)
        if category is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
        categories[category_id] = category

    items = [(item.name, item.category_id, normalize_item_amount(categories[item.category_id].name, item.amount_cents)) for item in data.items]

    try:
        transaction, transaction_items = repository.add_grouped_manual_transaction(db, ledger_id=ledger_id, payment_method_id=data.payment_method_id, merchant=data.merchant, transacted_at=data.transacted_at, memo=data.memo, total_cents=sum(amount for _, _, amount in items) + data.tax_cents + data.tip_cents, tax_cents=data.tax_cents, tip_cents=data.tip_cents, items=items)
        result = build_transaction_group_read(transaction=transaction, items=transaction_items)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise

def build_transaction_group_read(transaction: Transaction, items: list[TransactionItem]) -> TransactionGroupRead:
    """저장된 최종 총액과 품목 내역을 응답으로 만든다."""
    return TransactionGroupRead(id=transaction.id, ledger_id=transaction.ledger_id, payment_method_id=transaction.payment_method_id, merchant=transaction.merchant, transacted_at=transaction.transacted_at, memo=transaction.memo, source=transaction.source, total_cents=transaction.total_cents, tax_cents=transaction.tax_cents, tip_cents=transaction.tip_cents, items=[TransactionItemRead.model_validate(item) for item in items])

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
    """기존 품목 ID를 검증한 뒤 추가·수정·삭제를 한 번에 저장한다."""
    transaction = repository.find_ledger_transaction(db, ledger_id=ledger_id, transaction_id=transaction_id)
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    # 입력 출처와 무관하게 저장 후 품목을 최소 한 개 유지한다.
    if not data.items:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Transactions require at least one item")

    if repository.find_user_payment_method(db, payment_method_id=data.payment_method_id, user_id=user_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment method not found")

    existing_items = repository.list_transaction_items(db, [transaction_id])
    existing_by_id = {item.id: item for item in existing_items}
    requested_ids = [item.id for item in data.items if item.id is not None]
    requested_id_set = set(requested_ids)

    # 요청에서 빠진 기존 품목은 삭제하되, 중복되거나 다른 거래의 ID는 받지 않는다.
    if len(requested_ids) != len(requested_id_set) or not requested_id_set.issubset(existing_by_id):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Items must belong to the transaction and cannot be duplicated")

    items_to_delete = [item for item in existing_items if item.id not in requested_id_set]

    categories = {}
    for category_id in {item.category_id for item in data.items}:
        category = repository.find_global_category(db, category_id=category_id)
        if category is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
        categories[category_id] = category

    normalized_items = [(item, normalize_item_amount(categories[item.category_id].name, item.amount_cents)) for item in data.items]
    item_updates = [(existing_by_id[item.id], item.name, item.category_id, amount) for item, amount in normalized_items if item.id is not None]
    item_creations = [(item.name, item.category_id, amount) for item, amount in normalized_items if item.id is None]

    try:
        created_items = repository.apply_transaction_update(db, transaction=transaction, payment_method_id=data.payment_method_id, merchant=data.merchant, transacted_at=data.transacted_at, memo=data.memo, total_cents=sum(amount for _, amount in normalized_items) + data.tax_cents + data.tip_cents, tax_cents=data.tax_cents, tip_cents=data.tip_cents, item_updates=item_updates, item_creations=item_creations, item_deletions=items_to_delete)
        created_iter = iter(created_items)
        response_items = [existing_by_id[item.id] if item.id is not None else next(created_iter) for item in data.items]
        result = build_transaction_group_read(transaction=transaction, items=response_items)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise

def soft_delete_transaction(db: Session, ledger_id: UUID, transaction_id: UUID) -> None:
    """가계부의 활성 거래에 삭제 시각을 기록해 일반 조회에서 숨긴다."""
    transaction = repository.find_ledger_transaction(db, ledger_id=ledger_id, transaction_id=transaction_id)
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    try:
        repository.mark_transaction_deleted(db, transaction=transaction, deleted_at=datetime.now(UTC))
        db.commit()
    except Exception:
        db.rollback()
        raise

def restore_deleted_transaction_for_admin(db: Session, ledger_id: UUID, transaction_id: UUID) -> None:
    """관리자 운영 절차에서만 호출해 30일 이내 삭제 거래를 복구한다."""
    cutoff = datetime.now(UTC) - timedelta(days=30)
    transaction = repository.find_restorable_transaction(db, ledger_id=ledger_id, transaction_id=transaction_id, cutoff=cutoff)
    if transaction is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restorable transaction not found")

    try:
        repository.restore_transaction(db, transaction=transaction)
        db.commit()
    except Exception:
        db.rollback()
        raise

def purge_expired_transactions(db: Session, batch_size: int = 1000, pause_seconds: float = 0.1) -> int:
    """30일이 지난 거래와 품목을 묶음별로 삭제하고 각각 commit한다."""
    cutoff = datetime.now(UTC) - timedelta(days=30)
    total_deleted = 0

    while True:
        try:
            deleted_count = repository.delete_expired_transaction_batch(db, cutoff=cutoff, batch_size=batch_size)
            db.commit()
        except Exception:
            db.rollback()
            raise

        total_deleted += deleted_count
        if deleted_count < batch_size:
            return total_deleted
        sleep(pause_seconds)
