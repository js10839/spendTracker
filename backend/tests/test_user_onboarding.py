from datetime import UTC, datetime
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.auth.dependencies import get_current_user_id
from app.db.base import Base
from app.db.models.user import User, auth_users
from app.db.session import get_db
from app.main import app
from app.users import repository, router, service


@pytest.fixture
def onboarding_client(monkeypatch):
    """SQLite에서 인증과 PostgreSQL 전용 잠금을 대체해 API를 검증한다."""
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with engine.begin() as connection:
        connection.exec_driver_sql("ATTACH DATABASE ':memory:' AS auth")
        connection.exec_driver_sql("PRAGMA foreign_keys=ON")
        Base.metadata.create_all(connection)
    user_id = uuid4()
    with Session(engine, expire_on_commit=False) as db:
        db.execute(auth_users.insert().values(id=user_id))
        db.add(User(id=user_id, onboarding_completed=False))
        db.commit()
        monkeypatch.setattr(repository, "lock_bootstrap", lambda db, user_id: None)
        app.dependency_overrides[get_current_user_id] = lambda: user_id
        app.dependency_overrides[get_db] = lambda: db
        try:
            with TestClient(app) as client:
                yield client, db, user_id
        finally:
            app.dependency_overrides.clear()
    engine.dispose()


@pytest.mark.parametrize("nickname,expected", [("  Colin  ", "Colin"), ("", "Calm Otter"), ("   ", "Calm Otter")])
def test_complete_onboarding_saves_name_and_status(onboarding_client, monkeypatch, nickname, expected):
    """입력 이름과 빈 입력 모두 저장한 뒤 완료 상태가 된다."""
    client, db, user_id = onboarding_client
    monkeypatch.setattr(service, "generate_random_nickname", lambda: "Calm Otter")
    response = client.post("/users/me/onboarding/complete", json={"nickname": nickname})
    assert response.status_code == 200
    assert response.json()["nickname"] == expected
    db.expire_all()
    assert db.get(User, user_id).onboarding_completed is True


def test_completed_onboarding_does_not_replace_name(onboarding_client, monkeypatch):
    """완료 요청 재시도는 저장된 이름을 변경하지 않는다."""
    client, db, user_id = onboarding_client
    monkeypatch.setattr(service, "generate_random_nickname", lambda: "Calm Otter")
    assert client.post("/users/me/onboarding/complete", json={"nickname": ""}).status_code == 200
    response = client.post("/users/me/onboarding/complete", json={"nickname": "Different"})
    assert response.json()["nickname"] == "Calm Otter"
    db.expire_all()
    assert db.get(User, user_id).nickname == "Calm Otter"


def test_deletion_pending_cannot_complete_onboarding(onboarding_client):
    """삭제 진행 중인 계정은 가입 정보를 완료하지 못한다."""
    client, db, user_id = onboarding_client
    user = db.get(User, user_id)
    user.deletion_requested_at = datetime.now(UTC)
    db.commit()
    response = client.post("/users/me/onboarding/complete", json={"nickname": "Colin"})
    assert response.status_code == 409
    db.expire_all()
    assert db.get(User, user_id).onboarding_completed is False


def test_onboarding_requires_token():
    """인증되지 않은 요청은 가입 정보를 완료할 수 없다."""
    with TestClient(app) as client:
        response = client.post("/users/me/onboarding/complete", json={"nickname": "Colin"})
    assert response.status_code == 401


def test_nickname_suggestion_does_not_change_profile(onboarding_client, monkeypatch):
    """후보 조회는 이름과 가입 완료 상태를 저장하지 않는다."""
    client, db, user_id = onboarding_client
    monkeypatch.setattr(router, "generate_random_nickname", lambda: "Calm Otter")
    response = client.get("/users/me/nickname-suggestion")
    assert response.status_code == 200
    assert response.json() == {"nickname": "Calm Otter"}
    assert response.headers["cache-control"] == "no-store"
    db.expire_all()
    user = db.get(User, user_id)
    assert user.nickname is None
    assert user.onboarding_completed is False


def test_nickname_suggestion_requires_authentication():
    """로그인하지 않은 사용자는 후보를 요청할 수 없다."""
    with TestClient(app) as client:
        response = client.get("/users/me/nickname-suggestion")
    assert response.status_code == 401


def test_deletion_pending_cannot_get_nickname_suggestion(onboarding_client):
    """삭제 진행 중인 사용자는 후보 조회도 사용할 수 없다."""
    client, db, user_id = onboarding_client
    db.get(User, user_id).deletion_requested_at = datetime.now(UTC)
    db.commit()
    response = client.get("/users/me/nickname-suggestion")
    assert response.status_code == 409
