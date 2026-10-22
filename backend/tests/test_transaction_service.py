from datetime import date
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.db.models.category import Category
from app.db.models.payment_method import PaymentMethod
from app.db.models.transaction import Transaction
from app.transactions import repository, service
from app.transactions.schema import ManualTransactionCreate


def test_create_manual_transaction_commits_valid_expense(monkeypatch) -> None:
    """Service는 결제수단 소유권과 공통 카테고리를 확인한 뒤 commit한다."""
    user_id, ledger_id = uuid4(), uuid4()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=1299, transacted_at=date(2026, 10, 18), memo="Lunch")
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id, payment_method_id=data.payment_method_id, category_id=data.category_id, amount_cents=data.amount_cents, transacted_at=data.transacted_at, memo=data.memo)
    db = Mock()
    find_payment_method = Mock(return_value=PaymentMethod(id=data.payment_method_id, user_id=user_id, name="Visa", type="credit", closing_day=15, color="#123456"))
    find_category = Mock(return_value=Category(id=data.category_id, name="Food"))
    add_transaction = Mock(return_value=transaction)
    monkeypatch.setattr(repository, "find_user_payment_method", find_payment_method)
    monkeypatch.setattr(repository, "find_global_category", find_category)
    monkeypatch.setattr(repository, "add_manual_transaction", add_transaction)

    assert service.create_manual_transaction(db, ledger_id, user_id, data) is transaction

    find_payment_method.assert_called_once_with(db, payment_method_id=data.payment_method_id, user_id=user_id)
    find_category.assert_called_once_with(db, category_id=data.category_id)
    add_transaction.assert_called_once_with(db, ledger_id=ledger_id, payment_method_id=data.payment_method_id, category_id=data.category_id, amount_cents=1299, memo="Lunch", transacted_at=data.transacted_at)
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_create_manual_transaction_rejects_another_users_payment_method(monkeypatch) -> None:
    """다른 사용자 결제수단은 조회되지 않으므로 거래를 저장하지 않는다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=1299, transacted_at=date(2026, 10, 18))
    find_category = Mock()
    add_transaction = Mock()
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=None))
    monkeypatch.setattr(repository, "find_global_category", find_category)
    monkeypatch.setattr(repository, "add_manual_transaction", add_transaction)

    with pytest.raises(HTTPException) as raised:
        service.create_manual_transaction(db, uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    find_category.assert_not_called()
    add_transaction.assert_not_called()
    db.commit.assert_not_called()


def test_create_manual_transaction_rejects_unknown_category(monkeypatch) -> None:
    """공통 목록에 없는 카테고리로는 거래를 저장하지 않는다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=1299, transacted_at=date(2026, 10, 18))
    add_transaction = Mock()
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=data.payment_method_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=None))
    monkeypatch.setattr(repository, "add_manual_transaction", add_transaction)

    with pytest.raises(HTTPException) as raised:
        service.create_manual_transaction(db, uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    add_transaction.assert_not_called()
    db.commit.assert_not_called()


def test_create_manual_transaction_rolls_back_when_insert_fails(monkeypatch) -> None:
    """Repository 저장 오류가 나면 Service가 rollback하고 원래 오류를 전달한다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=1299, transacted_at=date(2026, 10, 18))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=data.payment_method_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=data.category_id)))
    monkeypatch.setattr(repository, "add_manual_transaction", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        service.create_manual_transaction(db, uuid4(), uuid4(), data)

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_list_ledger_transactions_returns_repository_results_without_committing(monkeypatch) -> None:
    """조회 Service는 기간을 전달하고 읽기 작업에 commit하지 않는다."""
    db = Mock()
    ledger_id = uuid4()
    transactions = [Transaction(id=uuid4(), ledger_id=ledger_id)]
    find_transactions = Mock(return_value=transactions)
    monkeypatch.setattr(repository, "list_ledger_transactions", find_transactions)

    result = service.list_ledger_transactions(db, ledger_id, date(2026, 10, 1), date(2026, 10, 31))

    assert result is transactions
    find_transactions.assert_called_once_with(db, ledger_id=ledger_id, start_date=date(2026, 10, 1), end_date=date(2026, 10, 31))
    db.commit.assert_not_called()


def test_list_ledger_transactions_rejects_reversed_dates(monkeypatch) -> None:
    """시작일이 종료일보다 늦으면 DB 조회 전에 요청을 거부한다."""
    find_transactions = Mock()
    monkeypatch.setattr(repository, "list_ledger_transactions", find_transactions)

    with pytest.raises(HTTPException) as raised:
        service.list_ledger_transactions(Mock(), uuid4(), date(2026, 11, 1), date(2026, 10, 31))

    assert raised.value.status_code == 422
    find_transactions.assert_not_called()


def test_update_manual_transaction_commits_valid_changes(monkeypatch) -> None:
    """Service는 수동 지출과 새 결제수단·카테고리를 검증한 뒤 commit한다."""
    db = Mock()
    ledger_id, transaction_id, user_id = uuid4(), uuid4(), uuid4()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=2500, transacted_at=date(2026, 10, 20), memo="Updated")
    transaction = Transaction(id=transaction_id, ledger_id=ledger_id, source="manual")
    find_transaction = Mock(return_value=transaction)
    find_payment_method = Mock(return_value=PaymentMethod(id=data.payment_method_id, user_id=user_id))
    find_category = Mock(return_value=Category(id=data.category_id))
    update_transaction = Mock(return_value=transaction)
    monkeypatch.setattr(repository, "find_ledger_manual_transaction", find_transaction)
    monkeypatch.setattr(repository, "find_user_payment_method", find_payment_method)
    monkeypatch.setattr(repository, "find_global_category", find_category)
    monkeypatch.setattr(repository, "update_manual_transaction", update_transaction)

    assert service.update_manual_transaction(db, ledger_id, transaction_id, user_id, data) is transaction

    find_transaction.assert_called_once_with(db, ledger_id=ledger_id, transaction_id=transaction_id)
    find_payment_method.assert_called_once_with(db, payment_method_id=data.payment_method_id, user_id=user_id)
    find_category.assert_called_once_with(db, category_id=data.category_id)
    update_transaction.assert_called_once_with(db, transaction=transaction, payment_method_id=data.payment_method_id, category_id=data.category_id, amount_cents=2500, transacted_at=data.transacted_at, memo="Updated")
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_update_manual_transaction_rejects_unknown_or_other_ledger_transaction(monkeypatch) -> None:
    """현재 가계부에서 찾을 수 없는 거래는 수정하지 않는다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=2500, transacted_at=date(2026, 10, 20))
    find_payment_method = Mock()
    update_transaction = Mock()
    monkeypatch.setattr(repository, "find_ledger_manual_transaction", Mock(return_value=None))
    monkeypatch.setattr(repository, "find_user_payment_method", find_payment_method)
    monkeypatch.setattr(repository, "update_manual_transaction", update_transaction)

    with pytest.raises(HTTPException) as raised:
        service.update_manual_transaction(db, uuid4(), uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    find_payment_method.assert_not_called()
    update_transaction.assert_not_called()
    db.commit.assert_not_called()


def test_update_manual_transaction_rejects_another_users_payment_method(monkeypatch) -> None:
    """다른 사용자 소유 결제수단으로는 지출을 바꾸지 않는다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=2500, transacted_at=date(2026, 10, 20))
    update_transaction = Mock()
    monkeypatch.setattr(repository, "find_ledger_manual_transaction", Mock(return_value=Transaction(id=uuid4(), source="manual")))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=None))
    monkeypatch.setattr(repository, "update_manual_transaction", update_transaction)

    with pytest.raises(HTTPException) as raised:
        service.update_manual_transaction(db, uuid4(), uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    update_transaction.assert_not_called()
    db.commit.assert_not_called()


def test_update_manual_transaction_rejects_unknown_category(monkeypatch) -> None:
    """공통 목록에 없는 카테고리는 수정에 사용할 수 없다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=2500, transacted_at=date(2026, 10, 20))
    update_transaction = Mock()
    monkeypatch.setattr(repository, "find_ledger_manual_transaction", Mock(return_value=Transaction(id=uuid4(), source="manual")))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=data.payment_method_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=None))
    monkeypatch.setattr(repository, "update_manual_transaction", update_transaction)

    with pytest.raises(HTTPException) as raised:
        service.update_manual_transaction(db, uuid4(), uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    update_transaction.assert_not_called()
    db.commit.assert_not_called()


def test_update_manual_transaction_rolls_back_when_write_fails(monkeypatch) -> None:
    """DB 변경에 실패하면 Service가 rollback하고 원래 오류를 전달한다."""
    db = Mock()
    data = ManualTransactionCreate(payment_method_id=uuid4(), category_id=uuid4(), amount_cents=2500, transacted_at=date(2026, 10, 20))
    monkeypatch.setattr(repository, "find_ledger_manual_transaction", Mock(return_value=Transaction(id=uuid4(), source="manual")))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=data.payment_method_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=data.category_id)))
    monkeypatch.setattr(repository, "update_manual_transaction", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        service.update_manual_transaction(db, uuid4(), uuid4(), uuid4(), data)

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()
