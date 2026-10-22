from datetime import date
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.category import Category
from app.db.models.payment_method import PaymentMethod
from app.db.models.transaction import Transaction


def find_user_payment_method(db: Session, payment_method_id: UUID, user_id: UUID) -> PaymentMethod | None:
    """결제수단이 현재 사용자 소유인지 확인하기 위해 조회한다."""
    statement = select(PaymentMethod).where(PaymentMethod.id == payment_method_id, PaymentMethod.user_id == user_id)
    return db.execute(statement=statement).scalar_one_or_none()

def find_global_category(db:Session, category_id: UUID) -> Category | None:
    """운영팀이 정의한 공통 카테고리 ID가 존재하는지 조회한다."""
    statement = select(Category).where(Category.id == category_id)
    return db.execute(statement=statement).scalar_one_or_none()

def add_manual_transaction(db: Session, ledger_id: UUID, payment_method_id: UUID, category_id: UUID, amount_cents: int, transacted_at: date, memo: str | None) -> Transaction:
    """검증된 수동 지출을 추가하고 생성된 ID를 확보한다."""
    transaction = Transaction(ledger_id=ledger_id, payment_method_id=payment_method_id, category_id=category_id, amount_cents=amount_cents, transacted_at=transacted_at, memo=memo, source="manual")
    db.add(transaction)
    db.flush()
    return transaction

def list_ledger_transactions(db: Session, ledger_id: UUID, start_date: date, end_date: date) -> list[Transaction]:
    """가계부의 지정 기간에 속한 삭제되지 않은 지출을 최신순으로 조회한다."""
    statement = select(Transaction).where(
        Transaction.ledger_id==ledger_id,
        Transaction.deleted_at.is_(None),
        Transaction.transacted_at >= start_date,
        Transaction.transacted_at <= end_date,
    ).order_by(Transaction.transacted_at.desc(), Transaction.created_at.desc())
    return list(db.scalars(statement=statement))

def find_ledger_manual_transaction(db: Session, ledger_id: UUID, transaction_id: UUID) -> Transaction | None:
    """가계부에 속한 삭제되지 않은 수동 지출을 조회한다."""
    statement = select(Transaction).where(Transaction.id==transaction_id, Transaction.ledger_id==ledger_id, Transaction.source=="manual", Transaction.deleted_at.is_(None),)
    return db.execute(statement=statement).scalar_one_or_none();

def update_manual_transaction(db: Session, transaction: Transaction, payment_method_id: UUID, category_id: UUID, amount_cents: int, transacted_at: date, memo: str | None) -> Transaction:
    """검증된 수동 지출의 입력값을 변경하고 DB에 반영한다."""
    transaction.payment_method_id = payment_method_id
    transaction.category_id = category_id
    transaction.amount_cents = amount_cents
    transaction.transacted_at = transacted_at
    transaction.memo = memo
    db.flush()
    return transaction