from unittest.mock import Mock
from uuid import uuid4

import pytest

from app.categories import repository as category_repo
from app.categories.defaults import DEFAULT_CATEGORIES
from app.db.models.ledger import Ledger
from app.db.models.user import User
from app.ledgers import repository as ledger_repo
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
    add_categories = Mock()
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=None))
    monkeypatch.setattr(user_repo, "add_user", add_user)
    monkeypatch.setattr(ledger_repo, "add_ledger", add_ledger)
    monkeypatch.setattr(ledger_repo, "add_ledger_member", add_member)
    monkeypatch.setattr(category_repo, "add_default_categories", add_categories)

    result = bootstrap_user(db, user_id, "Personal")

    assert result is user
    add_user.assert_called_once_with(db, user_id=user_id)
    add_ledger.assert_called_once_with(db, owner_user_id=user_id, name="Personal")
    add_member.assert_called_once_with(
        db, ledger_id=ledger.id, user_id=user_id, role="owner"
    )
    add_categories.assert_called_once_with(
        db, ledger_id=ledger.id, definitions=DEFAULT_CATEGORIES
    )
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_bootstrap_user_does_not_create_duplicates(monkeypatch) -> None:
    user_id = uuid4()
    existing_user = User(id=user_id)
    db = Mock()
    add_user = Mock()
    add_ledger = Mock()
    add_member = Mock()
    add_categories = Mock()
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=existing_user))
    monkeypatch.setattr(user_repo, "add_user", add_user)
    monkeypatch.setattr(ledger_repo, "add_ledger", add_ledger)
    monkeypatch.setattr(ledger_repo, "add_ledger_member", add_member)
    monkeypatch.setattr(category_repo, "add_default_categories", add_categories)

    result = bootstrap_user(db, user_id, "Personal")

    assert result is existing_user
    add_user.assert_not_called()
    add_ledger.assert_not_called()
    add_member.assert_not_called()
    add_categories.assert_not_called()
    db.commit.assert_not_called()


def test_bootstrap_user_rolls_back_on_failure(monkeypatch) -> None:
    user_id = uuid4()
    ledger = Ledger(id=uuid4(), name="Personal", owner_user_id=user_id)
    db = Mock()
    error = RuntimeError("category insert failed")
    monkeypatch.setattr(user_repo, "find_user_by_id", Mock(return_value=None))
    monkeypatch.setattr(user_repo, "add_user", Mock(return_value=User(id=user_id)))
    monkeypatch.setattr(ledger_repo, "add_ledger", Mock(return_value=ledger))
    monkeypatch.setattr(ledger_repo, "add_ledger_member", Mock())
    monkeypatch.setattr(
        category_repo, "add_default_categories", Mock(side_effect=error)
    )

    with pytest.raises(RuntimeError) as raised:
        bootstrap_user(db, user_id, "Personal")

    assert raised.value is error
    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_default_categories_are_unique_and_have_descriptions() -> None:
    names = [name for name, _description in DEFAULT_CATEGORIES]

    assert len(names) == len(set(names)) == 12
    assert all(description for _name, description in DEFAULT_CATEGORIES)


def test_default_category_repository_adds_rows_without_committing() -> None:
    ledger_id = uuid4()
    db = Mock()

    categories = category_repo.add_default_categories(db, ledger_id, DEFAULT_CATEGORIES)

    assert len(categories) == 12
    assert all(category.ledger_id == ledger_id for category in categories)
    assert all(category.is_default for category in categories)
    assert [(category.name, category.description) for category in categories] == (
        DEFAULT_CATEGORIES
    )
    db.add_all.assert_called_once_with(categories)
    db.flush.assert_called_once_with()
    db.commit.assert_not_called()
