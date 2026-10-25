from datetime import date
from unittest.mock import Mock
from uuid import uuid4

from app.db.models.category import Category
from app.db.models.transaction import Transaction
from app.db.models.transaction_item import TransactionItem
from app.transactions.repository import (
    add_grouped_manual_transaction,
    apply_transaction_update,
    find_global_category,
    find_ledger_transaction,
    list_ledger_transactions,
    list_transaction_items,
)


def test_find_global_category_uses_shared_id() -> None:
    """카테고리는 가계부 소속이 아니라 공통 ID로 확인한다."""
    category_id = uuid4()
    category = Category(id=category_id, name="Food")
    db = Mock()
    db.execute.return_value.scalar_one_or_none.return_value = category

    assert find_global_category(db, category_id) is category
    statement = db.execute.call_args.kwargs["statement"]
    assert statement.compile().params == {"id_1": category_id}


def test_add_grouped_transaction_flushes_parent_and_items_without_commit() -> None:
    """결제를 먼저 flush해 ID를 얻고 품목을 같은 세션에 추가한다."""
    ledger_id, payment_method_id, category_id, transaction_id = (uuid4() for _ in range(4))
    db = Mock()

    def assign_parent_id() -> None:
        """DB가 첫 flush에서 부모 PK를 채우는 동작을 흉내 낸다."""
        if db.flush.call_count == 1:
            db.add.call_args.args[0].id = transaction_id

    db.flush.side_effect = assign_parent_id
    transaction, items = add_grouped_manual_transaction(db, ledger_id, payment_method_id, "Cafe", date(2026, 10, 18), None, 1599, 100, 200, [("Sandwich", category_id, 1299)])

    assert isinstance(transaction, Transaction)
    assert transaction.ledger_id == ledger_id
    assert transaction.payment_method_id == payment_method_id
    assert transaction.total_cents == 1599
    assert transaction.tax_cents == 100
    assert transaction.tip_cents == 200
    assert transaction.source == "manual"
    assert len(items) == 1
    assert isinstance(items[0], TransactionItem)
    assert items[0].transaction_id == transaction_id
    assert items[0].category_id == category_id
    assert items[0].amount_cents == 1299
    db.add.assert_called_once_with(transaction)
    db.add_all.assert_called_once_with(items)
    assert db.flush.call_count == 2
    db.commit.assert_not_called()


def test_list_ledger_transactions_filters_ledger_dates_and_deleted_rows() -> None:
    """기간 조회는 가계부와 양끝 날짜, 삭제 여부로 결제를 제한한다."""
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
    assert "transactions.transacted_at >= " in sql
    assert "transactions.transacted_at <= " in sql
    assert "transactions.transacted_at DESC" in sql
    assert set(statement.compile().params.values()) == {ledger_id, date(2026, 10, 1), date(2026, 10, 31)}
    db.commit.assert_not_called()


def test_list_transaction_items_uses_parent_ids() -> None:
    """품목은 조회 대상 결제 ID들로 한 번에 가져온다."""
    transaction_id = uuid4()
    item = TransactionItem(id=uuid4(), transaction_id=transaction_id, category_id=uuid4(), name="Coffee", amount_cents=300)
    db = Mock()
    db.scalars.return_value = [item]

    assert list_transaction_items(db, [transaction_id]) == [item]
    statement = db.scalars.call_args.kwargs["statement"]
    assert "transaction_items.transaction_id IN" in str(statement)
    assert list(statement.compile().params.values()) == [[transaction_id]]
    db.commit.assert_not_called()


def test_find_ledger_transaction_accepts_any_source_but_not_deleted() -> None:
    """수정 대상은 가계부와 삭제 여부로 찾고 입력 출처로 제한하지 않는다."""
    ledger_id, transaction_id = uuid4(), uuid4()
    transaction = Transaction(id=transaction_id, ledger_id=ledger_id, source="receipt_parse")
    db = Mock()
    db.execute.return_value.scalar_one_or_none.return_value = transaction

    assert find_ledger_transaction(db, ledger_id, transaction_id) is transaction
    statement = db.execute.call_args.kwargs["statement"]
    sql = str(statement)
    assert "transactions.id =" in sql
    assert "transactions.ledger_id =" in sql
    assert "transactions.deleted_at IS NULL" in sql
    assert "transactions.source =" not in sql
    assert set(statement.compile().params.values()) == {transaction_id, ledger_id}


def test_apply_transaction_update_keeps_parent_and_item_ids() -> None:
    """Repository는 기존 품목 ID를 유지하고 총액·품목 금액을 바꾸되 commit하지 않는다."""
    transaction_id, item_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    transaction = Transaction(id=transaction_id, payment_method_id=uuid4(), merchant="Old", transacted_at=date(2026, 10, 1), tax_cents=0, tip_cents=0)
    item = TransactionItem(id=item_id, transaction_id=transaction_id, category_id=uuid4(), name="Old item", amount_cents=100)
    db = Mock()

    created = apply_transaction_update(db, transaction, payment_method_id, "New", date(2026, 10, 20), "Memo", 3000, 200, 300, [(item, "New item", category_id, 2500)], [], [])

    assert created == []
    assert transaction.id == transaction_id
    assert item.id == item_id
    assert transaction.payment_method_id == payment_method_id
    assert transaction.merchant == "New"
    assert transaction.total_cents == 3000
    assert transaction.tax_cents == 200
    assert transaction.tip_cents == 300
    assert item.name == "New item"
    assert item.category_id == category_id
    assert item.amount_cents == 2500
    db.flush.assert_called_once_with()
    db.commit.assert_not_called()


def test_apply_transaction_update_adds_and_deletes_items_without_commit() -> None:
    """요청에서 빠진 품목은 지우고 새 품목은 같은 세션에 추가한다."""
    transaction = Transaction(id=uuid4(), total_cents=2000)
    removed_item = TransactionItem(id=uuid4(), transaction_id=transaction.id)
    category_id = uuid4()
    db = Mock()

    created = apply_transaction_update(db, transaction, uuid4(), "Shop", date(2026, 10, 20), None, 2000, 0, 0, [], [("Apples", category_id, 500)], [removed_item])

    assert len(created) == 1
    assert created[0].transaction_id == transaction.id
    assert created[0].amount_cents == 500
    db.delete.assert_called_once_with(removed_item)
    db.add_all.assert_called_once_with(created)
    db.commit.assert_not_called()
