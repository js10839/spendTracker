from typing import Annotated
from unittest.mock import Mock
from uuid import uuid4

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.auth.dependencies import get_active_user_id, get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers import repository
from app.ledgers.dependencies import get_user_ledger


def test_member_can_access_ledger(monkeypatch) -> None:
    user_id = uuid4()
    ledger_id = uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    db = Mock()
    monkeypatch.setattr(repository, "find_member_ledger", lambda *_args: ledger)
    test_app = FastAPI()
    test_app.dependency_overrides[get_current_user_id] = lambda: user_id
    test_app.dependency_overrides[get_active_user_id] = lambda: user_id
    test_app.dependency_overrides[get_db] = lambda: db

    @test_app.get("/ledgers/{ledger_id}/probe")
    def probe(
        authorized_ledger: Annotated[Ledger, Depends(get_user_ledger)],
    ) -> dict[str, str]:
        return {"id": str(authorized_ledger.id)}

    response = TestClient(test_app).get(f"/ledgers/{ledger_id}/probe")

    assert response.status_code == 200
    assert response.json() == {"id": str(ledger_id)}


def test_nonmember_gets_not_found(monkeypatch) -> None:
    user_id = uuid4()
    ledger_id = uuid4()
    db = Mock()
    monkeypatch.setattr(repository, "find_member_ledger", lambda *_args: None)
    test_app = FastAPI()
    test_app.dependency_overrides[get_current_user_id] = lambda: user_id
    test_app.dependency_overrides[get_active_user_id] = lambda: user_id
    test_app.dependency_overrides[get_db] = lambda: db

    @test_app.get("/ledgers/{ledger_id}/probe")
    def probe(
        authorized_ledger: Annotated[Ledger, Depends(get_user_ledger)],
    ) -> dict[str, str]:
        return {"id": str(authorized_ledger.id)}

    response = TestClient(test_app).get(f"/ledgers/{ledger_id}/probe")

    assert response.status_code == 404


def test_membership_query_filters_both_ids() -> None:
    user_id = uuid4()
    ledger_id = uuid4()
    db = Mock()
    db.execute.return_value.scalar_one_or_none.return_value = None

    assert repository.find_member_ledger(db, ledger_id, user_id) is None

    statement = db.execute.call_args.args[0]
    parameters = statement.compile().params
    assert user_id in parameters.values()
    assert ledger_id in parameters.values()
