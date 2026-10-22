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
