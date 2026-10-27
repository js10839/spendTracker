from datetime import date, datetime
from uuid import UUID

from sqlalchemy import delete, or_, select
from sqlalchemy.orm import Session

from app.db.models.category import Category
from app.db.models.payment_method import PaymentMethod
from app.db.models.transaction import Transaction
from app.db.models.transaction_item import TransactionItem


def find_user_payment_method(db: Session, payment_method_id: UUID, user_id: UUID) -> PaymentMethod | None:
    """결제수단이 현재 사용자 소유인지 확인하기 위해 조회한다."""
    statement = select(PaymentMethod).where(PaymentMethod.id == payment_method_id, PaymentMethod.user_id == user_id)
    return db.execute(statement=statement).scalar_one_or_none()

def find_global_category(db:Session, category_id: UUID) -> Category | None:
    """운영팀이 정의한 공통 카테고리 ID가 존재하는지 조회한다."""
    statement = select(Category).where(Category.id == category_id)
    return db.execute(statement=statement).scalar_one_or_none()

def add_grouped_manual_transaction(db: Session, ledger_id: UUID, payment_method_id: UUID, merchant: str | None, transacted_at: date, memo: str | None, total_cents: int, tax_cents: int, tip_cents: int, items: list[tuple[str, UUID, int]]) -> tuple[Transaction, list[TransactionItem]]:
    """최종 총액과 선택적 품목을 추가하되 commit은 Service에 맡긴다."""
    transaction = Transaction(ledger_id=ledger_id, payment_method_id=payment_method_id, merchant=merchant, transacted_at=transacted_at, memo=memo, total_cents=total_cents, tax_cents=tax_cents, tip_cents=tip_cents, source="manual")
    db.add(transaction)
    db.flush()

    transaction_items=[
        TransactionItem(transaction_id=transaction.id, name=name, category_id=category_id, amount_cents=amount_cents) for name, category_id, amount_cents in items
    ]
    db.add_all(transaction_items)
    db.flush()
    return transaction, transaction_items

def list_ledger_transactions(db: Session, ledger_id: UUID, start_date: date, end_date: date) -> list[Transaction]:
    """가계부의 지정 기간에 속한 삭제되지 않은 지출을 최신순으로 조회한다."""
    statement = select(Transaction).where(
        Transaction.ledger_id==ledger_id,
        Transaction.deleted_at.is_(None),
        Transaction.transacted_at >= start_date,
        Transaction.transacted_at <= end_date,
    ).order_by(Transaction.transacted_at.desc(), Transaction.created_at.desc())
    return list(db.scalars(statement=statement))

def list_transaction_items(db: Session, transaction_ids: list[UUID]) -> list[TransactionItem]:
    """조회한 결제들에 속한 품목을 한 번에 가져온다."""
    statement = select(TransactionItem).where(TransactionItem.transaction_id.in_(transaction_ids)).order_by(TransactionItem.created_at, TransactionItem.id)
    return list(db.scalars(statement=statement))

def find_ledger_transaction(db: Session, ledger_id: UUID, transaction_id: UUID) -> Transaction | None:
    """가계부에 속한 삭제되지 않은 결제를 입력 방식과 무관하게 조회한다."""
    statement = select(Transaction).where(Transaction.id==transaction_id, Transaction.ledger_id==ledger_id, Transaction.deleted_at.is_(None))
    return db.execute(statement=statement).scalar_one_or_none()

def mark_transaction_deleted(db: Session, transaction: Transaction, deleted_at: datetime) -> None:
    """결제 삭제 시각만 기록하고 품목은 복구를 위해 보관한다."""
    transaction.deleted_at = deleted_at
    db.flush()

def find_restorable_transaction(db: Session, ledger_id: UUID, transaction_id: UUID, cutoff: datetime) -> Transaction | None:
    """해당 가계부에서 30일 보관 기간이 남은 삭제 거래를 조회한다."""
    statement = select(Transaction).where(Transaction.id==transaction_id, Transaction.ledger_id==ledger_id, Transaction.deleted_at.is_not(None), Transaction.deleted_at > cutoff)
    return db.execute(statement=statement).scalar_one_or_none()

def restore_transaction(db: Session, transaction: Transaction) -> None:
    """삭제 시각을 지워 거래와 보관 중인 품목을 다시 조회 가능하게 한다."""
    transaction.deleted_at = None
    db.flush()

def delete_expired_transaction_batch(db: Session, cutoff: datetime, batch_size: int) -> int:
    """30일이 지난 거래를 한 묶음 잠그고 품목부터 영구 삭제한다."""
    statement = select(Transaction.id).where(Transaction.deleted_at.is_not(None), Transaction.deleted_at <= cutoff).order_by(Transaction.deleted_at, Transaction.id).limit(batch_size).with_for_update()
    transaction_ids = list(db.scalars(statement))
    if not transaction_ids:
        return 0

    db.execute(delete(TransactionItem).where(TransactionItem.transaction_id.in_(transaction_ids)))
    db.execute(delete(Transaction).where(Transaction.id.in_(transaction_ids)))
    return len(transaction_ids)

def apply_transaction_update(db: Session, transaction: Transaction, payment_method_id: UUID, merchant: str | None, transacted_at: date, memo: str | None, total_cents: int, tax_cents: int, tip_cents: int, item_updates: list[tuple[TransactionItem, str, UUID, int]], item_creations: list[tuple[str, UUID, int]], item_deletions: list[TransactionItem]) -> list[TransactionItem]:
    """결제와 품목의 추가·수정·삭제를 flush하되 commit은 하지 않는다."""
    transaction.payment_method_id = payment_method_id
    transaction.merchant = merchant
    transaction.transacted_at = transacted_at
    transaction.memo = memo
    transaction.total_cents = total_cents
    transaction.tax_cents = tax_cents
    transaction.tip_cents = tip_cents

    for item, name, category_id, amount_cents in item_updates:
        item.name = name
        item.category_id = category_id
        item.amount_cents = amount_cents

    for item in item_deletions:
        db.delete(item)

    created_items = [TransactionItem(transaction_id=transaction.id, name=name, category_id=category_id, amount_cents=amount_cents) for name, category_id, amount_cents in item_creations]
    db.add_all(created_items)
    db.flush()
    return created_items

def search_transaction_items(db: Session, ledger_id: UUID, start_date: date, end_date: date, query: str, payment_method_id: UUID | None = None) -> list[tuple[TransactionItem, Transaction, Category]]:
    """기간 내 품목·가게·카테고리명 일치 품목을 선택한 카드로 좁혀 찾는다."""
    escaped = query.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")
    pattern = f"%{escaped}%"

    statement = (
        select(TransactionItem, Transaction, Category)
        .join(Transaction, TransactionItem.transaction_id == Transaction.id)
        .join(Category, TransactionItem.category_id == Category.id)
        .where(
            Transaction.ledger_id == ledger_id,
            Transaction.deleted_at.is_(None),
            Transaction.transacted_at >= start_date,
            Transaction.transacted_at <= end_date,
            or_(
                TransactionItem.name.ilike(pattern, escape="\\"),
                Transaction.merchant.ilike(pattern, escape="\\"),
                Category.name.ilike(pattern, escape="\\"),
            ),
        )
    )
    if payment_method_id is not None:
        statement = statement.where(Transaction.payment_method_id == payment_method_id)
    statement = statement.order_by(Transaction.transacted_at.desc(), TransactionItem.created_at, TransactionItem.id)
    return [(item, transaction, category) for item, transaction, category in db.execute(statement)]
