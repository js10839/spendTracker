from uuid import UUID

from sqlalchemy import delete, func, select, update
from sqlalchemy.engine import Connection, Row

from app.db.tables import (
    income_records,
    income_sources,
    ledger_members,
    ledgers,
    payment_methods,
    transaction_items,
    transactions,
    users,
)


def find_user_by_id(db: Connection, user_id: UUID) -> Row | None:
    """Supabase Auth UUID와 같은 ID의 앱 프로필을 조회한다."""
    return db.execute(select(users).where(users.c.id == user_id)).one_or_none()


def lock_user_by_id(db: Connection, user_id: UUID, shared: bool = False) -> Row | None:
    """쓰기 요청과 계정 삭제가 같은 사용자 행을 동시에 변경하지 않게 잠근다."""
    statement = select(users).where(users.c.id == user_id).with_for_update(read=shared)
    return db.execute(statement).one_or_none()


def add_user(db: Connection, user_id: UUID) -> Row:
    """앱 프로필을 추가하고 commit 없이 INSERT를 실행한다."""
    statement = users.insert().values(id=user_id).returning(users)
    return db.execute(statement).one()


def update_user_nickname(db: Connection, user: Row, nickname: str) -> Row:
    """사용자 프로필의 표시 이름을 변경한다."""
    if user.nickname == nickname:
        return user
    statement = users.update().where(users.c.id == user.id).values(nickname=nickname)
    return db.execute(statement.returning(users)).one()


def list_owned_ledger_ids(db: Connection, user_id: UUID) -> list[UUID]:
    """계정 삭제 시 사용자가 소유한 가계부 ID를 조회한다."""
    statement = select(ledgers.c.id).where(ledgers.c.owner_user_id == user_id)
    return list(db.scalars(statement))


def list_pending_deletion_user_ids(db: Connection) -> list[UUID]:
    """Auth 계정 삭제를 재시도해야 하는 사용자 ID를 조회한다."""
    statement = (
        select(users.c.id)
        .where(users.c.deletion_requested_at.is_not(None))
        .order_by(users.c.deletion_requested_at, users.c.id)
    )
    return list(db.scalars(statement))


def delete_ledger_transactions(db: Connection, ledger_ids: list[UUID]) -> None:
    """소유 가계부의 거래 품목과 거래를 순서대로 삭제한다."""
    transaction_ids = select(transactions.c.id).where(
        transactions.c.ledger_id.in_(ledger_ids)
    )
    db.execute(
        delete(transaction_items).where(
            transaction_items.c.transaction_id.in_(transaction_ids)
        )
    )
    db.execute(delete(transactions).where(transactions.c.ledger_id.in_(ledger_ids)))


def delete_ledger_income(db: Connection, ledger_ids: list[UUID]) -> None:
    """소유 가계부의 실제 수입과 예정 수입을 삭제한다."""
    db.execute(delete(income_records).where(income_records.c.ledger_id.in_(ledger_ids)))
    db.execute(delete(income_sources).where(income_sources.c.ledger_id.in_(ledger_ids)))


def delete_user_data(db: Connection, user_id: UUID, ledger_ids: list[UUID]) -> None:
    """사용자의 앱 데이터를 삭제하고 프로필에 삭제 진행 상태를 기록한다."""
    # 공유 가계부 도입 시 계정 삭제에 따른 소유권 이전과 탈퇴 정책을 정해야 한다.
    db.execute(delete(ledger_members).where(ledger_members.c.user_id == user_id))
    db.execute(delete(ledgers).where(ledgers.c.id.in_(ledger_ids)))
    db.execute(delete(payment_methods).where(payment_methods.c.user_id == user_id))


def mark_user_deletion_requested(db: Connection, user_id: UUID) -> None:
    """최초 삭제 요청 시각을 유지하고 프로필 이름을 지운다."""
    db.execute(
        update(users)
        .where(users.c.id == user_id)
        .values(
            nickname=None,
            deletion_requested_at=func.coalesce(
                users.c.deletion_requested_at, func.now()
            ),
        )
    )


def lock_bootstrap(db: Connection, user_id: UUID) -> None:
    """같은 사용자의 bootstrap 요청을 트랜잭션이 끝날 때까지 순서대로 처리한다."""
    statement = select(
        func.pg_advisory_xact_lock(func.hashtextextended(f"user-bootstrap{user_id}", 0))
    )
    db.execute(statement)


def complete_onboarding(db: Connection, user: Row, nickname: str) -> Row:
    """표시 이름과 가입 정보 완료 상태를 함께 반영한다."""
    statement = (
        users.update()
        .where(users.c.id == user.id)
        .values(nickname=nickname, onboarding_completed=True)
        .returning(users)
    )
    return db.execute(statement).one()
