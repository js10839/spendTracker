from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user_id
from app.categories import repository as categories_repository
from app.categories import router as categories_router
from app.db.models.category import Category
from app.db.session import get_db
from app.main import app


def test_list_categories_reads_global_catalog_without_committing() -> None:
    """Repository는 가계부 조건 없이 공통 목록을 읽고 commit하지 않는다."""
    db = Mock()
    category = Category(id=uuid4(), name="Food", is_default=True)
    db.execute.return_value.scalars.return_value.all.return_value = [category]

    assert categories_repository.list_categories(db) == [category]
    assert "ledger_id" not in str(db.execute.call_args.kwargs["statement"])
    db.commit.assert_not_called()


def test_list_categories_returns_global_catalog_to_authenticated_user(monkeypatch) -> None:
    """인증된 사용자는 가계부를 선택하지 않고 공통 목록을 조회한다."""
    user_id = uuid4()
    category = Category(id=uuid4(), name="Food", icon=None, is_default=True)
    db = Mock()
    list_global_categories = Mock(return_value=[category])
    monkeypatch.setattr(categories_router, "list_global_categories", list_global_categories)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get("/categories")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [{"id": str(category.id), "name": "Food", "icon": None, "is_default": True}]
    list_global_categories.assert_called_once_with(db)


def test_list_categories_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰 없는 요청은 공통 목록을 읽을 수 없다."""
    list_global_categories = Mock()
    monkeypatch.setattr(categories_router, "list_global_categories", list_global_categories)

    with TestClient(app) as client:
        response = client.get("/categories")

    assert response.status_code == 401
    list_global_categories.assert_not_called()
