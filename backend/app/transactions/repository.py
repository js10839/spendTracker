from datetime import date, datetime
from uuid import UUID

from sqlalchemy import delete, or_, select, update
from sqlalchemy.engine import Connection, Row

from app.db.rows import update_row
from app.db.tables import categories, payment_methods, transaction_items, transactions


def find_user_payment_method(
    db: Connection, payment_method_id: UUID, user_id: UUID
) -> Row | None:
    """결제수단이 현재 사용자 소유인지 확인하기 위해 조회한다."""
    statement = select(payment_methods).where(
        payment_methods.c.id == payment_method_id, payment_methods.c.user_id == user_id
    )
    return db.execute(statement).one_or_none()


def find_global_category(db: Connection, category_id: UUID) -> Row | None:
    """운영팀이 정의한 공통 카테고리 ID가 존재하는지 조회한다."""
    statement = select(categories).where(categories.c.id == category_id)
    return db.execute(statement).one_or_none()


def add_grouped_manual_transaction(
    db: Connection,
    ledger_id: UUID,
    payment_method_id: UUID,
    merchant: str | None,
    transacted_at: date,
    memo: str | None,
    total_cents: int,
    tax_cents: int,
    tip_cents: int,
    items: list[tuple[str, UUID, int]],
) -> tuple[Row, list[Row]]:
    """최종 총액과 선택적 품목을 추가하되 commit은 Service에 맡긴다."""
    statement = (
        transactions.insert()
        .values(
            ledger_id=ledger_id,
            payment_method_id=payment_method_id,
            merchant=merchant,
            transacted_at=transacted_at,
            memo=memo,
            total_cents=total_cents,
            tax_cents=tax_cents,
            tip_cents=tip_cents,
            source="manual",
        )
        .returning(transactions)
    )
    transaction = db.execute(statement).one()
    return transaction, _insert_items(db, transaction.id, items)


def _insert_items(
    db: Connection, transaction_id: UUID, items: list[tuple[str, UUID, int]]
) -> list[Row]:
    if not items:
        return []
    values = [
        {
            "transaction_id": transaction_id,
            "name": name,
            "category_id": category_id,
            "amount_cents": amount,
        }
        for name, category_id, amount in items
    ]
    statement = transaction_items.insert().returning(
        transaction_items, sort_by_parameter_order=True
    )
    return list(db.execute(statement, values))


def list_ledger_transactions(
    db: Connection,
    ledger_id: UUID,
    start_date: date,
    end_date: date,
    payment_method_id: UUID | None = None,
) -> list[Row]:
    """가계부의 지정 기간에 속한 삭제되지 않은 지출을 최신순으로 조회한다."""
    statement = (
        select(transactions)
        .where(
            transactions.c.ledger_id == ledger_id,
            transactions.c.deleted_at.is_(None),
            transactions.c.transacted_at >= start_date,
            transactions.c.transacted_at <= end_date,
        )
        .order_by(transactions.c.transacted_at.desc(), transactions.c.created_at.desc())
    )
    if payment_method_id is not None:
        statement = statement.where(
            transactions.c.payment_method_id == payment_method_id
        )
    return list(db.execute(statement))


def list_transaction_items(db: Connection, transaction_ids: list[UUID]) -> list[Row]:
    """조회한 결제들에 속한 품목을 한 번에 가져온다."""
    statement = (
        select(transaction_items)
        .where(transaction_items.c.transaction_id.in_(transaction_ids))
        .order_by(transaction_items.c.created_at, transaction_items.c.id)
    )
    return list(db.execute(statement))


def find_ledger_transaction(
    db: Connection, ledger_id: UUID, transaction_id: UUID
) -> Row | None:
    """가계부에 속한 삭제되지 않은 결제를 입력 방식과 무관하게 조회한다."""
    statement = select(transactions).where(
        transactions.c.id == transaction_id,
        transactions.c.ledger_id == ledger_id,
        transactions.c.deleted_at.is_(None),
    )
    return db.execute(statement).one_or_none()


def update_transaction_memo(
    db: Connection, ledger_id: UUID, transaction_id: UUID, memo: str | None
):
    """가계부의 활성 거래 메모만 변경하고 결과를 반환한다."""
    statement = (
        update(transactions)
        .where(
            transactions.c.id == transaction_id,
            transactions.c.ledger_id == ledger_id,
            transactions.c.deleted_at.is_(None),
        )
        .values(memo=memo)
        .returning(transactions.c.id, transactions.c.memo)
    )
    return db.execute(statement).one_or_none()


def mark_transaction_deleted(
    db: Connection, transaction: Row, deleted_at: datetime
) -> None:
    """결제 삭제 시각만 기록하고 품목은 복구를 위해 보관한다."""
    update_row(db, transactions, transaction, deleted_at=deleted_at)


def find_restorable_transaction(
    db: Connection, ledger_id: UUID, transaction_id: UUID, cutoff: datetime
) -> Row | None:
    """해당 가계부에서 30일 보관 기간이 남은 삭제 거래를 조회한다."""
    statement = select(transactions).where(
        transactions.c.id == transaction_id,
        transactions.c.ledger_id == ledger_id,
        transactions.c.deleted_at.is_not(None),
        transactions.c.deleted_at > cutoff,
    )
    return db.execute(statement).one_or_none()


def restore_transaction(db: Connection, transaction: Row) -> None:
    """삭제 시각을 지워 거래와 보관 중인 품목을 다시 조회 가능하게 한다."""
    update_row(db, transactions, transaction, deleted_at=None)


def delete_expired_transaction_batch(
    db: Connection, cutoff: datetime, batch_size: int
) -> int:
    """30일이 지난 거래를 한 묶음 잠그고 품목부터 영구 삭제한다."""
    statement = (
        select(transactions.c.id)
        .where(
            transactions.c.deleted_at.is_not(None), transactions.c.deleted_at <= cutoff
        )
        .order_by(transactions.c.deleted_at, transactions.c.id)
        .limit(batch_size)
        .with_for_update()
    )
    transaction_ids = list(db.scalars(statement))
    if not transaction_ids:
        return 0

    db.execute(
        delete(transaction_items).where(
            transaction_items.c.transaction_id.in_(transaction_ids)
        )
    )
    db.execute(delete(transactions).where(transactions.c.id.in_(transaction_ids)))
    return len(transaction_ids)


def apply_transaction_update(
    db: Connection,
    transaction: Row,
    payment_method_id: UUID,
    merchant: str | None,
    transacted_at: date,
    memo: str | None,
    total_cents: int,
    tax_cents: int,
    tip_cents: int,
    item_updates: list[tuple[Row, str, UUID, int]],
    item_creations: list[tuple[str, UUID, int]],
    item_deletions: list[Row],
) -> tuple[Row, dict[UUID, Row], list[Row]]:
    """결제와 품목의 추가·수정·삭제를 한 트랜잭션에서 실행한다."""
    transaction = update_row(
        db,
        transactions,
        transaction,
        payment_method_id=payment_method_id,
        merchant=merchant,
        transacted_at=transacted_at,
        memo=memo,
        total_cents=total_cents,
        tax_cents=tax_cents,
        tip_cents=tip_cents,
    )
    updated_items = {
        item.id: update_row(
            db,
            transaction_items,
            item,
            name=name,
            category_id=category_id,
            amount_cents=amount_cents,
        )
        for item, name, category_id, amount_cents in item_updates
    }
    if item_deletions:
        statement = transaction_items.delete().where(
            transaction_items.c.transaction_id == transaction.id,
            transaction_items.c.id.in_([item.id for item in item_deletions]),
        )
        db.execute(statement)
    return transaction, updated_items, _insert_items(db, transaction.id, item_creations)


def search_transaction_items(
    db: Connection,
    ledger_id: UUID,
    start_date: date,
    end_date: date,
    query: str,
    payment_method_id: UUID | None = None,
) -> list[Row]:
    """기간 내 품목·가게·카테고리명 일치 품목을 선택한 카드로 좁혀 찾는다."""
    escaped = query.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")
    pattern = f"%{escaped}%"

    statement = (
        select(
            transaction_items.c.id.label("item_id"),
            transaction_items.c.name,
            transaction_items.c.amount_cents,
            transactions.c.id.label("transaction_id"),
            transactions.c.merchant,
            transactions.c.transacted_at,
            categories.c.id.label("category_id"),
            categories.c.name.label("category_name"),
        )
        .select_from(transaction_items)
        .join(transactions, transaction_items.c.transaction_id == transactions.c.id)
        .join(categories, transaction_items.c.category_id == categories.c.id)
        .where(
            transactions.c.ledger_id == ledger_id,
            transactions.c.deleted_at.is_(None),
            transactions.c.transacted_at >= start_date,
            transactions.c.transacted_at <= end_date,
            or_(
                transaction_items.c.name.ilike(pattern, escape="\\"),
                transactions.c.merchant.ilike(pattern, escape="\\"),
                categories.c.name.ilike(pattern, escape="\\"),
            ),
        )
    )
    if payment_method_id is not None:
        statement = statement.where(
            transactions.c.payment_method_id == payment_method_id
        )
    statement = statement.order_by(
        transactions.c.transacted_at.desc(),
        transaction_items.c.created_at,
        transaction_items.c.id,
    )
    return list(db.execute(statement))
