from datetime import date
from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient

from app.auth.dependencies import get_active_user_id, get_current_user_id
from app.db.models.income_record import IncomeRecord
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.income import router as income_router
from app.ledgers import repository as ledgers_repository
from app.ledgers.dependencies import get_user_ledger
from app.main import app


def test_create_income_record_returns_created_paycheck(monkeypatch) -> None:
    """가계부 멤버의 Paycheck 요청을 Service에 전달하고 생성 결과를 반환한다."""
    user_id, ledger_id, record_id = uuid4(), uuid4(), uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_source_id=None, payment_method_id=None, income_type="paycheck", from_name="Company", amount_cents=250000, received_at=date(2026, 10, 23), memo=None)
    create_record = Mock(return_value=record)
    db = Mock()
    monkeypatch.setattr(income_router, "create_income_record", create_record)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: ledger
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/income-records", json={"income_type": "paycheck", "amount_cents": 250000, "received_at": "2026-10-23", "from_name": "Company"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json() == {"id": str(record_id), "ledger_id": str(ledger_id), "income_source_id": None, "payment_method_id": None, "income_type": "paycheck", "from_name": "Company", "amount_cents": 250000, "received_at": "2026-10-23", "memo": None}
    create_record.assert_called_once()
    assert create_record.call_args.args == (db,)
    assert create_record.call_args.kwargs["ledger_id"] == ledger_id
    assert create_record.call_args.kwargs["user_id"] == user_id


def test_create_income_record_rejects_nonmembers(monkeypatch) -> None:
    """가계부 접근 권한이 없으면 수입 생성 Service를 호출하지 않는다."""
    user_id, ledger_id = uuid4(), uuid4()
    create_record = Mock()
    monkeypatch.setattr(income_router, "create_income_record", create_record)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/income-records", json={"income_type": "other", "amount_cents": 1000, "received_at": "2026-10-23"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    create_record.assert_not_called()


def test_create_income_record_requires_authentication(monkeypatch) -> None:
    """토큰이 없으면 수입 생성 Service를 호출하지 않는다."""
    create_record = Mock()
    monkeypatch.setattr(income_router, "create_income_record", create_record)

    with TestClient(app) as client:
        response = client.post(f"/ledgers/{uuid4()}/income-records", json={"income_type": "other", "amount_cents": 1000, "received_at": "2026-10-23"})

    assert response.status_code == 401
    create_record.assert_not_called()


def test_create_income_record_rejects_refund_type(monkeypatch) -> None:
    """Refund는 더 이상 수입 유형이 아니므로 Service 호출 전에 거부한다."""
    user_id, ledger_id = uuid4(), uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    create_record = Mock()
    monkeypatch.setattr(income_router, "create_income_record", create_record)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: ledger
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/income-records", json={"income_type": "refund", "amount_cents": 1000, "received_at": "2026-10-23", "from_name": "Store", "applied_to": str(uuid4())})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    create_record.assert_not_called()
