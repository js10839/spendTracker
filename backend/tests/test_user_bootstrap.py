from unittest.mock import Mock
from uuid import uuid4

import pytest

from app.db.models.ledger import Ledger
from app.db.models.payment_method import PaymentMethod
from app.db.models.user import User
from app.ledgers import repository as ledger_repo
from app.payment_methods import repository as payment_method_repo
from app.users import repository as user_repo
from app.users.service import bootstrap_user


def test_bootstrap_user_creates_initial_data(monkeypatch) -> None:
    user_id = uuid4()
    user = User(id=user_id)
    ledger = Ledger(id=uuid4(), name="Personal", owner_user_id=user_id)
    db = Mock()
    add_user = Mock(return_value=user)
    add_ledger = Mock(return_value=ledger)
    add_member = Mock()
    add_cash = Mock()
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=None))
    monkeypatch.setattr(user_repo, "add_user", add_user)
    monkeypatch.setattr(ledger_repo, "add_ledger", add_ledger)
    monkeypatch.setattr(ledger_repo, "add_ledger_member", add_member)
    monkeypatch.setattr(payment_method_repo, "add_payment_method", add_cash)

    result = bootstrap_user(db, user_id, "Personal")

    assert result is user
    add_user.assert_called_once_with(db, user_id=user_id)
    add_ledger.assert_called_once_with(db, owner_user_id=user_id, name="Personal")
    add_member.assert_called_once_with(
        db, ledger_id=ledger.id, user_id=user_id, role="owner"
    )
    add_cash.assert_called_once_with(db, user_id=user_id, name="Cash", method_type="cash-like", closing_day=None, color="#FCA05A")
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_bootstrap_user_does_not_create_duplicates(monkeypatch) -> None:
    user_id = uuid4()
    existing_user = User(id=user_id)
    db = Mock()
    add_user = Mock()
    add_ledger = Mock()
    add_member = Mock()
    find_cash = Mock(return_value=PaymentMethod(id=uuid4(), user_id=user_id, name="Cash", type="cash-like", color="#FCA05A"))
    add_cash = Mock()
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=existing_user))
    monkeypatch.setattr(user_repo, "add_user", add_user)
    monkeypatch.setattr(ledger_repo, "add_ledger", add_ledger)
    monkeypatch.setattr(ledger_repo, "add_ledger_member", add_member)
    monkeypatch.setattr(payment_method_repo, "find_cash_payment_method", find_cash)
    monkeypatch.setattr(payment_method_repo, "add_payment_method", add_cash)

    result = bootstrap_user(db, user_id, "Personal")

    assert result is existing_user
    add_user.assert_not_called()
    add_ledger.assert_not_called()
    add_member.assert_not_called()
    find_cash.assert_called_once_with(db, user_id=user_id)
    add_cash.assert_not_called()
    db.commit.assert_not_called()


def test_bootstrap_user_adds_cash_to_existing_profile(monkeypatch) -> None:
    """기존 프로필이 Cash 없이 만들어졌다면 재초기화 시 Cash만 추가한다."""
    user_id = uuid4()
    existing_user = User(id=user_id)
    db = Mock()
    add_user, add_ledger, add_cash = Mock(), Mock(), Mock()
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=existing_user))
    monkeypatch.setattr(user_repo, "add_user", add_user)
    monkeypatch.setattr(ledger_repo, "add_ledger", add_ledger)
    monkeypatch.setattr(payment_method_repo, "find_cash_payment_method", Mock(return_value=None))
    monkeypatch.setattr(payment_method_repo, "add_payment_method", add_cash)

    assert bootstrap_user(db, user_id, "Personal") is existing_user

    add_user.assert_not_called()
    add_ledger.assert_not_called()
    add_cash.assert_called_once_with(db, user_id=user_id, name="Cash", method_type="cash-like", closing_day=None, color="#FCA05A")
    db.commit.assert_called_once_with()


def test_bootstrap_user_rolls_back_on_failure(monkeypatch) -> None:
    user_id = uuid4()
    ledger = Ledger(id=uuid4(), name="Personal", owner_user_id=user_id)
    db = Mock()
    error = RuntimeError("membership insert failed")
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=None))
    monkeypatch.setattr(user_repo, "add_user", Mock(return_value=User(id=user_id)))
    monkeypatch.setattr(ledger_repo, "add_ledger", Mock(return_value=ledger))
    monkeypatch.setattr(ledger_repo, "add_ledger_member", Mock(side_effect=error))

    with pytest.raises(RuntimeError) as raised:
        bootstrap_user(db, user_id, "Personal")

    assert raised.value is error
    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_bootstrap_user_rolls_back_when_cash_creation_fails(monkeypatch) -> None:
    """Cash 생성 실패 시 프로필·가계부 생성도 함께 rollback한다."""
    user_id = uuid4()
    db = Mock()
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=None))
    monkeypatch.setattr(user_repo, "add_user", Mock(return_value=User(id=user_id)))
    monkeypatch.setattr(ledger_repo, "add_ledger", Mock(return_value=Ledger(id=uuid4(), owner_user_id=user_id)))
    monkeypatch.setattr(ledger_repo, "add_ledger_member", Mock())
    monkeypatch.setattr(payment_method_repo, "add_payment_method", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        bootstrap_user(db, user_id, "Personal")

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()
