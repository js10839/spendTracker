from datetime import date
from unittest.mock import Mock
from uuid import uuid4

from app.db.models.category import Category
from app.db.models.transaction import Transaction
from app.transactions.repository import add_manual_transaction, find_global_category


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
