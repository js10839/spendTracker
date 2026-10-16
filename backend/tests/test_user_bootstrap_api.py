from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user_id
from app.db.models.user import User
from app.db.session import get_db
from app.main import app
from app.users import router as users_router


def test_bootstrap_api_uses_authenticated_user_id(monkeypatch) -> None:
    """인증된 사용자 ID로 Service를 호출하고 프로필 ID를 반환한다."""
    user_id = uuid4()
    db = Mock()
    bootstrap_user = Mock(return_value=User(id=user_id))
    monkeypatch.setattr(users_router, "bootstrap_user", bootstrap_user)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.post("/users/me/bootstrap")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {"user_id": str(user_id)}
    bootstrap_user.assert_called_once_with(db, user_id=user_id, ledger_name="Personal")


def test_bootstrap_api_rejects_unauthenticated_requests(monkeypatch) -> None:
    """Bearer 토큰이 없는 요청은 Service 호출 전에 거부한다."""
    bootstrap_user = Mock()
    monkeypatch.setattr(users_router, "bootstrap_user", bootstrap_user)

    with TestClient(app) as client:
        response = client.post("/users/me/bootstrap")

    assert response.status_code == 401
    bootstrap_user.assert_not_called()
