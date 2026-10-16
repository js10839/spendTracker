from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.ledger import Ledger
from app.db.models.ledger_member import LedgerMember


def find_member_ledger(db: Session, ledger_id: UUID, user_id: UUID) -> Ledger | None:
    """사용자가 멤버인 가계부만 조회한다."""
    statement = (
        select(Ledger)
        .join(LedgerMember, LedgerMember.ledger_id == Ledger.id)
        .where(Ledger.id == ledger_id, LedgerMember.user_id == user_id)
    )
    return db.execute(statement).scalar_one_or_none()


def add_ledger(db: Session, owner_user_id: UUID, name: str) -> Ledger:
    """개인 가계부를 추가하고 멤버십 생성에 쓸 ID를 확보한다."""
    ledger = Ledger(owner_user_id=owner_user_id, name=name)
    db.add(ledger)
    db.flush()
    return ledger


def add_ledger_member(
    db: Session, ledger_id: UUID, user_id: UUID, role: str
) -> LedgerMember:
    """가계부 멤버십을 추가하되 commit은 Service에 맡긴다."""
    member = LedgerMember(ledger_id=ledger_id, user_id=user_id, role=role)
    db.add(member)
    db.flush()
    return member

def list_member_ledgers(db: Session, user_id: UUID) -> list[Ledger]:
    """사용자가 멤버인 가계부 목록을 조회한다."""
    statement = (
        select(Ledger).join(LedgerMember, LedgerMember.ledger_id == Ledger.id).where(LedgerMember.user_id == user_id)
    )
    return list(db.execute(statement=statement).scalars().all())