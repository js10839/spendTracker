from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user_id
from app.categories import repository as categories_repository
from app.categories import router as categories_router
from app.db.models.category import Category
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers import repository as ledgers_repository
from app.main import app


def test_list_categories_filters_by_ledger_without_committing() -> None:
    """Repository는 지정한 가계부의 카테고리만 조회 조건에 넣는다."""
    db = Mock()
    ledger_id = uuid4()
    category = Category(id=uuid4(), ledger_id=ledger_id, name="Food", is_default=True)
    db.execute.return_value.scalars.return_value.all.return_value = [category]

    assert categories_repository.list_categories(db, ledger_id) == [category]
    assert ledger_id in db.execute.call_args.kwargs["statement"].compile().params.values()
    db.commit.assert_not_called()


def test_list_categories_returns_current_ledgers_categories(monkeypatch) -> None:
    """멤버는 접근 가능한 가계부의 카테고리 목록을 조회한다."""
    user_id = uuid4()
    ledger_id = uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    category = Category(id=uuid4(), ledger_id=ledger_id, name="Food", icon=None, is_default=True)
    db = Mock()
    list_ledger_categories = Mock(return_value=[category])
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=ledger))
    monkeypatch.setattr(categories_router, "list_ledger_categories", list_ledger_categories)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get(f"/ledgers/{ledger_id}/categories")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [{"id": str(category.id), "name": "Food", "icon": None, "is_default": True}]
    list_ledger_categories.assert_called_once_with(db, ledger_id=ledger_id)


def test_list_categories_rejects_nonmembers(monkeypatch) -> None:
    """가계부 멤버가 아니면 카테고리 조회 Service를 호출하지 않는다."""
    user_id = uuid4()
    ledger_id = uuid4()
    list_ledger_categories = Mock()
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    monkeypatch.setattr(categories_router, "list_ledger_categories", list_ledger_categories)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.get(f"/ledgers/{ledger_id}/categories")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    list_ledger_categories.assert_not_called()


def test_list_categories_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰 없는 요청은 카테고리 조회 Service를 호출하지 않는다."""
    list_ledger_categories = Mock()
    monkeypatch.setattr(categories_router, "list_ledger_categories", list_ledger_categories)

    with TestClient(app) as client:
        response = client.get(f"/ledgers/{uuid4()}/categories")

    assert response.status_code == 401
    list_ledger_categories.assert_not_called()
