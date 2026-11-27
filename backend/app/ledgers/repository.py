from uuid import UUID

from sqlalchemy import select
from sqlalchemy.engine import Connection, Row

from app.db.tables import ledger_members, ledgers


def find_member_ledger(db: Connection, ledger_id: UUID, user_id: UUID) -> Row | None:
    """사용자가 멤버인 가계부만 조회한다."""
    statement = (
        select(ledgers)
        .join(ledger_members, ledger_members.c.ledger_id == ledgers.c.id)
        .where(ledgers.c.id == ledger_id, ledger_members.c.user_id == user_id)
    )
    return db.execute(statement).one_or_none()


def add_ledger(db: Connection, owner_user_id: UUID, name: str) -> Row:
    """개인 가계부를 추가하고 멤버십 생성에 쓸 ID를 확보한다."""
    statement = (
        ledgers.insert()
        .values(owner_user_id=owner_user_id, name=name)
        .returning(ledgers)
    )
    return db.execute(statement).one()


def add_ledger_member(db: Connection, ledger_id: UUID, user_id: UUID, role: str) -> Row:
    """가계부 멤버십을 추가하되 commit은 Service에 맡긴다."""
    statement = (
        ledger_members.insert()
        .values(ledger_id=ledger_id, user_id=user_id, role=role)
        .returning(ledger_members)
    )
    return db.execute(statement).one()


def list_member_ledgers(db: Connection, user_id: UUID) -> list[Row]:
    """사용자가 멤버인 가계부 목록을 조회한다."""
    statement = (
        select(ledgers)
        .join(ledger_members, ledger_members.c.ledger_id == ledgers.c.id)
        .where(ledger_members.c.user_id == user_id)
    )
    return list(db.execute(statement))
