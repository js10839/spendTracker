from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user_id
from app.db.models.user import User
from app.db.session import get_db
from app.main import app
from app.users.service import update_user_profile


def test_get_profile_returns_authenticated_users_profile() -> None:
    """인증된 사용자 ID로 조회한 프로필을 응답한다."""
    user_id = uuid4()
    db = Mock()
    db.get.return_value = User(id=user_id, nickname=None, plan="free")
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get("/users/me")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {"id": str(user_id), "nickname": None, "plan": "free"}
    db.get.assert_called_once_with(User, user_id)


def test_get_profile_returns_404_before_bootstrap() -> None:
    """앱 프로필이 없는 인증 사용자는 404를 받는다."""
    db = Mock()
    db.get.return_value = None
    app.dependency_overrides[get_current_user_id] = lambda: uuid4()
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get("/users/me")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json() == {"detail": "User profile not found"}


def test_get_profile_requires_authentication() -> None:
    """토큰이 없는 요청은 프로필을 조회할 수 없다."""
    db = Mock()
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get("/users/me")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 401
    db.get.assert_not_called()


def test_update_profile_changes_authenticated_users_nickname() -> None:
    """본인의 표시 이름을 변경하고 수정된 프로필을 반환한다."""
    user_id = uuid4()
    user = User(id=user_id, nickname="Old", plan="free")
    db = Mock()
    db.get.return_value = user
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.patch("/users/me", json={"nickname": "Mellow Otter"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {"id": str(user_id), "nickname": "Mellow Otter", "plan": "free"}
    db.get.assert_called_once_with(User, user_id)
    db.flush.assert_called_once_with()
    db.commit.assert_called_once_with()


def test_update_profile_rolls_back_on_database_error() -> None:
    """이름을 저장하지 못하면 트랜잭션을 되돌린다."""
    user_id = uuid4()
    db = Mock()
    db.get.return_value = User(id=user_id, nickname="Old", plan="free")
    db.flush.side_effect = RuntimeError("DB error")

    with pytest.raises(RuntimeError, match="DB error"):
        update_user_profile(db, user_id, "New")

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()
