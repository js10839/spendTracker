from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.ledger import Ledger
from app.db.models.ledger_member import LedgerMember


def find_member_ledger(db: Session, ledger_id: UUID, user_id: UUID) -> Ledger | None:
    statement = (
        select(Ledger)
        .join(LedgerMember, LedgerMember.ledger_id == Ledger.id)
        .where(Ledger.id == ledger_id, LedgerMember.user_id == user_id)
    )
    return db.execute(statement).scalar_one_or_none()
