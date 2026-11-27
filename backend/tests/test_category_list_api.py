from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine

from app.auth.dependencies import get_active_user_id
from app.categories import repository as categories_repository
from app.categories import router as categories_router
from app.db.session import get_db
from app.db.tables import categories
from app.main import app


def test_list_categories_reads_global_catalog_without_committing() -> None:
    """Repository는 가계부 조건 없이 공통 목록을 읽고 commit하지 않는다."""
    connection = Mock()
    category = {"id": uuid4(), "name": "Food", "is_default": True}
    connection.execute.return_value.mappings.return_value = [category]

    assert categories_repository.list_categories(connection) == [category]
    assert "ledger_id" not in str(connection.execute.call_args.args[0])
    connection.commit.assert_not_called()


def test_list_categories_returns_global_catalog_to_authenticated_user() -> None:
    """인증된 사용자는 가계부를 선택하지 않고 공통 목록을 조회한다."""
    user_id = uuid4()
    food_id = uuid4()
    travel_id = uuid4()
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False})

    with engine.begin() as connection:
        categories.create(connection)
        connection.execute(
            categories.insert(),
            [
                {
                    "id": travel_id,
                    "name": "Travel",
                    "icon": "plane",
                    "is_default": False,
                },
                {"id": food_id, "name": "Food", "icon": None, "is_default": True},
            ],
        )
        app.dependency_overrides[get_active_user_id] = lambda: user_id
        app.dependency_overrides[get_db] = lambda: connection

        try:
            with TestClient(app) as client:
                response = client.get("/categories")
        finally:
            app.dependency_overrides.clear()

    engine.dispose()
    assert response.status_code == 200
    assert response.json() == [
        {"id": str(food_id), "name": "Food", "icon": None, "is_default": True},
        {"id": str(travel_id), "name": "Travel", "icon": "plane", "is_default": False},
    ]


def test_list_categories_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰 없는 요청은 공통 목록을 읽을 수 없다."""
    list_global_categories = Mock()
    monkeypatch.setattr(
        categories_router, "list_global_categories", list_global_categories
    )

    with TestClient(app) as client:
        response = client.get("/categories")

    assert response.status_code == 401
    list_global_categories.assert_not_called()
