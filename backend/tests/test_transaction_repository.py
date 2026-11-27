from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import Mock
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, select

from app.db.tables import metadata, transaction_items, transactions
from app.transactions.repository import (
    add_grouped_manual_transaction,
    apply_transaction_update,
    delete_expired_transaction_batch,
    find_global_category,
    find_ledger_transaction,
    find_restorable_transaction,
    list_ledger_transactions,
    list_transaction_items,
)


def test_find_global_category_uses_shared_id() -> None:
    """카테고리는 가계부 소속이 아니라 공통 ID로 확인한다."""
    category_id = uuid4()
    category = SimpleNamespace(id=category_id, name="Food")
    db = Mock()
    db.execute.return_value.one_or_none.return_value = category

    assert find_global_category(db, category_id) is category
    statement = db.execute.call_args.args[0]
    assert statement.compile().params == {"id_1": category_id}


@pytest.fixture
def connection():
    engine = create_engine("sqlite://")
    try:
        metadata.create_all(engine, tables=[transactions, transaction_items])
        with engine.connect() as db:
            yield db
    finally:
        engine.dispose()


def test_add_grouped_transaction_inserts_parent_and_items_without_commit(
    connection,
) -> None:
    ledger_id, payment_method_id, category_id = (uuid4() for _ in range(3))
    transaction, items = add_grouped_manual_transaction(
        connection,
        ledger_id,
        payment_method_id,
        "Cafe",
        date(2026, 10, 18),
        None,
        1599,
        100,
        200,
        [("Sandwich", category_id, 1299), ("Coffee", category_id, 0)],
    )

    assert transaction.ledger_id == ledger_id
    assert transaction.payment_method_id == payment_method_id
    assert (transaction.total_cents, transaction.tax_cents, transaction.tip_cents) == (
        1599,
        100,
        200,
    )
    assert transaction.source == "manual"
    assert [item.name for item in items] == ["Sandwich", "Coffee"]
    assert items[0].transaction_id == transaction.id
    assert items[0].category_id == category_id
    assert items[0].amount_cents == 1299
    connection.rollback()
    assert connection.execute(select(transactions)).all() == []
    assert connection.execute(select(transaction_items)).all() == []


def test_list_ledger_transactions_filters_ledger_dates_and_deleted_rows() -> None:
    """기간 조회는 가계부와 양끝 날짜, 삭제 여부로 결제를 제한한다."""
    ledger_id = uuid4()
    transaction = SimpleNamespace(id=uuid4(), ledger_id=ledger_id)
    db = Mock()
    db.execute.return_value = [transaction]

    result = list_ledger_transactions(
        db, ledger_id, date(2026, 10, 1), date(2026, 10, 31)
    )

    assert result == [transaction]
    statement = db.execute.call_args.args[0]
    sql = str(statement)
    assert "transactions.ledger_id =" in sql
    assert "transactions.deleted_at IS NULL" in sql
    assert "transactions.transacted_at >= " in sql
    assert "transactions.transacted_at <= " in sql
    assert "transactions.transacted_at DESC" in sql
    assert set(statement.compile().params.values()) == {
        ledger_id,
        date(2026, 10, 1),
        date(2026, 10, 31),
    }
    db.commit.assert_not_called()


def test_list_ledger_transactions_filters_selected_payment_method() -> None:
    """선택한 카드의 거래만 조회하도록 결제수단 조건을 추가한다."""
    ledger_id, payment_method_id = uuid4(), uuid4()
    db = Mock()
    db.execute.return_value = []

    assert (
        list_ledger_transactions(
            db, ledger_id, date(2026, 10, 1), date(2026, 10, 31), payment_method_id
        )
        == []
    )

    statement = db.execute.call_args.args[0]
    assert "transactions.payment_method_id =" in str(statement)
    assert payment_method_id in statement.compile().params.values()


def test_list_transaction_items_uses_parent_ids() -> None:
    """품목은 조회 대상 결제 ID들로 한 번에 가져온다."""
    transaction_id = uuid4()
    item = SimpleNamespace(
        id=uuid4(),
        transaction_id=transaction_id,
        category_id=uuid4(),
        name="Coffee",
        amount_cents=300,
    )
    db = Mock()
    db.execute.return_value = [item]

    assert list_transaction_items(db, [transaction_id]) == [item]
    statement = db.execute.call_args.args[0]
    assert "transaction_items.transaction_id IN" in str(statement)
    assert list(statement.compile().params.values()) == [[transaction_id]]
    db.commit.assert_not_called()


def test_find_ledger_transaction_accepts_any_source_but_not_deleted() -> None:
    """수정 대상은 가계부와 삭제 여부로 찾고 입력 출처로 제한하지 않는다."""
    ledger_id, transaction_id = uuid4(), uuid4()
    transaction = SimpleNamespace(
        id=transaction_id, ledger_id=ledger_id, source="receipt_parse"
    )
    db = Mock()
    db.execute.return_value.one_or_none.return_value = transaction

    assert find_ledger_transaction(db, ledger_id, transaction_id) is transaction
    statement = db.execute.call_args.args[0]
    sql = str(statement)
    assert "transactions.id =" in sql
    assert "transactions.ledger_id =" in sql
    assert "transactions.deleted_at IS NULL" in sql
    assert "transactions.source =" not in sql
    assert set(statement.compile().params.values()) == {transaction_id, ledger_id}


def test_apply_transaction_update_keeps_parent_and_item_ids(connection) -> None:
    ledger_id, old_method_id, payment_method_id, category_id = (
        uuid4() for _ in range(4)
    )
    transaction, [item] = add_grouped_manual_transaction(
        connection,
        ledger_id,
        old_method_id,
        "Old",
        date(2026, 10, 1),
        None,
        100,
        0,
        0,
        [("Old item", uuid4(), 100)],
    )
    connection.commit()

    updated, items, created = apply_transaction_update(
        connection,
        transaction,
        payment_method_id,
        "New",
        date(2026, 10, 20),
        "Memo",
        3000,
        200,
        300,
        [(item, "New item", category_id, 2500)],
        [],
        [],
    )

    assert created == []
    assert updated.id == transaction.id
    assert updated.payment_method_id == payment_method_id
    assert updated.merchant == "New"
    assert (updated.total_cents, updated.tax_cents, updated.tip_cents) == (
        3000,
        200,
        300,
    )
    assert items[item.id].id == item.id
    assert items[item.id].name == "New item"
    assert items[item.id].category_id == category_id
    assert items[item.id].amount_cents == 2500
    connection.rollback()
    assert connection.execute(select(transactions)).one().merchant == "Old"
    assert connection.execute(select(transaction_items)).one().name == "Old item"


def test_apply_transaction_update_adds_and_deletes_items_without_commit(
    connection,
) -> None:
    ledger_id, method_id, category_id = (uuid4() for _ in range(3))
    transaction, [removed] = add_grouped_manual_transaction(
        connection,
        ledger_id,
        method_id,
        "Shop",
        date(2026, 10, 20),
        None,
        100,
        0,
        0,
        [("Old item", category_id, 100)],
    )
    connection.commit()

    _, updated, [created] = apply_transaction_update(
        connection,
        transaction,
        method_id,
        "Shop",
        date(2026, 10, 20),
        None,
        500,
        0,
        0,
        [],
        [("Apples", category_id, 500)],
        [removed],
    )

    assert updated == {}
    assert created.transaction_id == transaction.id
    assert created.amount_cents == 500
    assert connection.execute(select(transaction_items)).one().id == created.id
    connection.rollback()
    assert connection.execute(select(transaction_items)).one().id == removed.id


def test_find_restorable_transaction_filters_expired_rows() -> None:
    """복구 조회는 해당 가계부와 30일 컷오프를 함께 적용한다."""
    ledger_id, transaction_id = uuid4(), uuid4()
    cutoff = datetime.now(UTC) - timedelta(days=30)
    db = Mock()

    find_restorable_transaction(db, ledger_id, transaction_id, cutoff)

    statement = db.execute.call_args.args[0]
    sql = str(statement)
    assert "transactions.deleted_at IS NOT NULL" in sql
    assert "transactions.deleted_at >" in sql
    assert set(statement.compile().params.values()) == {
        ledger_id,
        transaction_id,
        cutoff,
    }


def test_delete_expired_transaction_batch_removes_items_first() -> None:
    """만료된 거래 ID만 고르고 품목을 부모보다 먼저 지운다."""
    transaction_id = uuid4()
    cutoff = datetime.now(UTC) - timedelta(days=30)
    db = Mock()
    db.scalars.return_value = [transaction_id]

    result = delete_expired_transaction_batch(db, cutoff, 1000)

    assert result == 1
    select_statement = db.scalars.call_args.args[0]
    assert "transactions.deleted_at <=" in str(select_statement)
    assert "FOR UPDATE" in str(select_statement)
    statements = [call.args[0] for call in db.execute.call_args_list]
    assert "DELETE FROM transaction_items" in str(statements[0])
    assert "DELETE FROM transactions" in str(statements[1])
    db.commit.assert_not_called()
