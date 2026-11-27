from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.engine import Connection, Row

from app.db.tables import payment_methods


def add_payment_method(
    db: Connection,
    user_id: UUID,
    name: str,
    method_type: str,
    closing_day: int | None,
    color: str,
) -> Row:
    """결제수단을 추가하고 생성된 ID가 포함된 행을 반환한다."""
    statement = (
        payment_methods.insert()
        .values(
            user_id=user_id,
            type=method_type,
            closing_day=closing_day,
            name=name,
            color=color,
        )
        .returning(payment_methods)
    )
    return db.execute(statement).one()


def find_user_payment_method(
    db: Connection, payment_method_id: UUID, user_id: UUID
) -> Row | None:
    """요청한 결제수단이 현재 사용자의 지갑에 있을 때만 반환한다."""
    statement = select(payment_methods).where(
        payment_methods.c.id == payment_method_id,
        payment_methods.c.user_id == user_id,
    )
    return db.execute(statement).one_or_none()


def find_cash_payment_method(db: Connection, user_id: UUID) -> Row | None:
    """사용자 지갑에 이미 현금 결제수단이 있는지 확인한다."""
    statement = (
        select(payment_methods)
        .where(
            payment_methods.c.user_id == user_id,
            payment_methods.c.type == "cash-like",
            func.lower(payment_methods.c.name) == "cash",
        )
        .limit(1)
    )
    return db.execute(statement).one_or_none()


def list_payment_methods(db: Connection, user_id: UUID) -> list[Row]:
    """현재 사용자에게 속한 결제수단을 가계부와 무관하게 조회한다."""
    statement = (
        select(payment_methods)
        .where(payment_methods.c.user_id == user_id)
        .order_by(payment_methods.c.created_at, payment_methods.c.id)
    )
    return list(db.execute(statement))


def update_payment_method_details(
    db: Connection,
    payment_method: Row,
    *,
    name: str | None = None,
    closing_day: int | None = None,
    update_closing_day: bool = False,
    color: str | None = None,
) -> Row:
    """요청에 포함된 결제수단 필드만 반영한다."""
    changes = {}
    if name is not None and name != payment_method.name:
        changes["name"] = name
    if update_closing_day and closing_day != payment_method.closing_day:
        changes["closing_day"] = closing_day
    if color is not None and color != payment_method.color:
        changes["color"] = color
    if not changes:
        return payment_method

    statement = (
        payment_methods.update()
        .where(
            payment_methods.c.id == payment_method.id,
            payment_methods.c.user_id == payment_method.user_id,
        )
        .values(**changes)
        .returning(payment_methods)
    )
    return db.execute(statement).one()
