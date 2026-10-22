from datetime import date
from unittest.mock import Mock
from uuid import uuid4

from app.db.models.category import Category
from app.db.models.transaction import Transaction
from app.transactions.repository import (
    add_manual_transaction,
    find_global_category,
    find_ledger_manual_transaction,
    list_ledger_transactions,
    update_manual_transaction,
)


def test_find_global_category_uses_shared_id() -> None:
    """지출 입력 시 카테고리는 가계부 소속이 아니라 공통 ID로 확인한다."""
    category_id = uuid4()
    category = Category(id=category_id, name="Food")
    db = Mock()
    db.execute.return_value.scalar_one_or_none.return_value = category

    assert find_global_category(db, category_id) is category
    statement = db.execute.call_args.kwargs["statement"]
    assert statement.compile().params == {"id_1": category_id}


def test_add_manual_transaction_flushes_without_committing() -> None:
    """Repository는 수동 지출을 세션에 추가하고 commit은 Service에 맡긴다."""
    db = Mock()
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()

    transaction = add_manual_transaction(db, ledger_id, payment_method_id, category_id, 1299, date(2026, 10, 18), "Lunch")

    assert isinstance(transaction, Transaction)
    assert transaction.ledger_id == ledger_id
    assert transaction.payment_method_id == payment_method_id
    assert transaction.category_id == category_id
    assert transaction.amount_cents == 1299
    assert transaction.source == "manual"
    db.add.assert_called_once_with(transaction)
    db.flush.assert_called_once_with()
    db.commit.assert_not_called()


def test_list_ledger_transactions_filters_ledger_dates_and_deleted_rows() -> None:
    """조회 쿼리는 가계부, 양끝 날짜, 삭제 여부를 기준으로 지출을 제한한다."""
    ledger_id = uuid4()
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id)
    db = Mock()
    db.scalars.return_value = [transaction]

    result = list_ledger_transactions(db, ledger_id, date(2026, 10, 1), date(2026, 10, 31))

    assert result == [transaction]
    statement = db.scalars.call_args.kwargs["statement"]
    sql = str(statement)
    assert "transactions.ledger_id =" in sql
    assert "transactions.deleted_at IS NULL" in sql
    assert "transactions.transacted_at >=" in sql
    assert "transactions.transacted_at <=" in sql
    assert "transactions.transacted_at DESC" in sql
    assert set(statement.compile().params.values()) == {ledger_id, date(2026, 10, 1), date(2026, 10, 31)}
    db.commit.assert_not_called()


def test_find_ledger_manual_transaction_limits_update_target() -> None:
    """수정 대상 조회는 거래 ID와 가계부를 함께 확인하고 삭제된 수동 지출을 제외한다."""
    ledger_id, transaction_id = uuid4(), uuid4()
    transaction = Transaction(id=transaction_id, ledger_id=ledger_id, source="manual")
    db = Mock()
    db.execute.return_value.scalar_one_or_none.return_value = transaction

    assert find_ledger_manual_transaction(db, ledger_id, transaction_id) is transaction

    statement = db.execute.call_args.kwargs["statement"]
    sql = str(statement)
    assert "transactions.id =" in sql
    assert "transactions.ledger_id =" in sql
    assert "transactions.source =" in sql
    assert "transactions.deleted_at IS NULL" in sql
    assert set(statement.compile().params.values()) == {transaction_id, ledger_id, "manual"}


def test_update_manual_transaction_flushes_without_committing() -> None:
    """Repository는 검증된 필드만 바꾸고 commit은 Service에 맡긴다."""
    transaction = Transaction(id=uuid4(), payment_method_id=uuid4(), category_id=uuid4(), amount_cents=100, transacted_at=date(2026, 10, 1), memo="Before")
    payment_method_id, category_id = uuid4(), uuid4()
    db = Mock()

    result = update_manual_transaction(db, transaction, payment_method_id, category_id, 2500, date(2026, 10, 20), None)

    assert result is transaction
    assert transaction.payment_method_id == payment_method_id
    assert transaction.category_id == category_id
    assert transaction.amount_cents == 2500
    assert transaction.transacted_at == date(2026, 10, 20)
    assert transaction.memo is None
    db.flush.assert_called_once_with()
    db.commit.assert_not_called()
