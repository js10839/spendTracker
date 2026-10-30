from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient

from app.auth.dependencies import get_active_user_id, get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers import repository
from app.ledgers import router as ledgers_router
from app.main import app


def test_list_ledgers_returns_current_users_ledgers(monkeypatch) -> None:
    """인증된 사용자의 가계부 목록을 Service에서 받아 응답한다."""
    user_id = uuid4()
    ledger = Ledger(id=uuid4(), name="Personal", owner_user_id=user_id)
    db = Mock()
    list_user_ledgers = Mock(return_value=[ledger])
    monkeypatch.setattr(ledgers_router, "list_user_ledgers", list_user_ledgers)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get("/ledgers")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [{"id": str(ledger.id), "name": "Personal"}]
    list_user_ledgers.assert_called_once_with(db, user_id=user_id)


def test_list_ledgers_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰이 없는 요청은 Service를 호출하기 전에 거부한다."""
    list_user_ledgers = Mock()
    monkeypatch.setattr(ledgers_router, "list_user_ledgers", list_user_ledgers)

    with TestClient(app) as client:
        response = client.get("/ledgers")

    assert response.status_code == 401
    list_user_ledgers.assert_not_called()


def test_list_member_ledgers_filters_user_id_without_committing() -> None:
    """Repository는 사용자 멤버십으로 조회하고 commit하지 않는다."""
    user_id = uuid4()
    ledger = Ledger(id=uuid4(), name="Personal", owner_user_id=user_id)
    db = Mock()
    db.execute.return_value.scalars.return_value.all.return_value = [ledger]

    assert repository.list_member_ledgers(db, user_id) == [ledger]

    statement = (
        db.execute.call_args.args[0]
        if db.execute.call_args.args
        else db.execute.call_args.kwargs["statement"]
    )
    assert user_id in statement.compile().params.values()
    assert "ledger_members" in str(statement)
    db.commit.assert_not_called()
