from uuid import UUID

from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from app.db.models.day_note import DayNote
from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.db.models.ledger import Ledger
from app.db.models.ledger_member import LedgerMember
from app.db.models.payment_method import PaymentMethod
from app.db.models.transaction import Transaction
from app.db.models.transaction_item import TransactionItem
from app.db.models.user import User


def find_user_by_id(db: Session, user_id: UUID) -> User | None:
    """Supabase Auth UUID와 같은 ID의 앱 프로필을 조회한다."""
    return db.get(User, user_id)

def lock_user_by_id(db: Session, user_id: UUID, shared: bool = False) -> User | None:
    """쓰기 요청과 계정 삭제가 같은 사용자 행을 동시에 변경하지 않게 잠근다."""
    statement = select(User).where(User.id == user_id).with_for_update(read=shared)
    return db.scalars(statement).one_or_none()


def add_user(db: Session, user_id: UUID) -> User:
    """앱 프로필을 추가하고 commit 없이 INSERT를 실행한다."""
    user = User(id=user_id)
    db.add(user)
    db.flush()
    return user

def update_user_nickname(db: Session, user: User, nickname: str) -> User:
    """사용자 프로필의 표시 이름을 변경한다."""
    user.nickname = nickname
    db.flush()
    return user

def list_owned_ledger_ids(db: Session, user_id: UUID) -> list[UUID]:
    """계정 삭제 시 사용자가 소유한 가계부 ID를 조회한다."""
    statement = select(Ledger.id).where(Ledger.owner_user_id==user_id)
    return list(db.scalars(statement=statement))

def delete_ledger_transactions(db: Session, ledger_ids: list[UUID]) -> None:
    """소유 가계부의 거래 품목과 거래를 순서대로 삭제한다."""
    transaction_ids = select(Transaction.id).where(Transaction.ledger_id.in_(ledger_ids))
    db.execute(delete(TransactionItem).where(TransactionItem.transaction_id.in_(transaction_ids)))
    db.execute(delete(Transaction).where(Transaction.ledger_id.in_(ledger_ids)))

def delete_ledger_income_and_notes(db: Session, ledger_ids: list[UUID]) -> None:
    """소유 가계부의 수입 기록과 날짜 메모를 삭제한다."""
    db.execute(delete(IncomeRecord).where(IncomeRecord.ledger_id.in_(ledger_ids)))
    db.execute(delete(IncomeSource).where(IncomeSource.ledger_id.in_(ledger_ids)))
    db.execute(delete(DayNote).where(DayNote.ledger_id.in_(ledger_ids)))

def delete_user_data(db: Session, user_id: UUID, ledger_ids: list[UUID]) -> None:
    """사용자의 앱 데이터를 삭제하고 프로필에 삭제 진행 상태를 기록한다."""
    # 공유 가계부 도입 시 계정 삭제에 따른 소유권 이전과 탈퇴 정책을 정해야 한다.
    db.execute(delete(LedgerMember).where(LedgerMember.user_id==user_id))
    db.execute(delete(Ledger).where(Ledger.id.in_(ledger_ids)))
    db.execute(delete(PaymentMethod).where(PaymentMethod.user_id == user_id))

def mark_user_deletion_requested(db: Session, user_id: UUID) -> None:
    """최초 삭제 요청 시각을 유지하고 프로필 이름을 지운다."""
    db.execute(update(User).where(User.id == user_id).values(nickname=None, deletion_requested_at=func.coalesce(User.deletion_requested_at, func.now())))
