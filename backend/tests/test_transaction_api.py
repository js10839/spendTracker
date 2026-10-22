from datetime import date
from unittest.mock import Mock
from uuid import uuid4

from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.models.transaction import Transaction
from app.db.session import get_db
from app.ledgers import repository as ledgers_repository
from app.ledgers.dependencies import get_user_ledger
from app.main import app
from app.transactions import router as transactions_router


def test_create_manual_transaction_returns_created_expense(monkeypatch) -> None:
    """인증된 가계부 멤버의 수동 지출 요청은 생성된 거래를 반환한다."""
    user_id, ledger_id = uuid4(), uuid4()
    payment_method_id, category_id = uuid4(), uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id, payment_method_id=payment_method_id, category_id=category_id, amount_cents=1299, transacted_at=date(2026, 10, 18), memo="Lunch", source="manual")
    create_transaction = Mock(return_value=transaction)
    db = Mock()
    monkeypatch.setattr(transactions_router, "create_manual_transaction", create_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: ledger
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/transactions", json={"payment_method_id": str(payment_method_id), "category_id": str(category_id), "amount_cents": 1299, "transacted_at": "2026-10-18", "memo": "Lunch"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json() == {"id": str(transaction.id), "ledger_id": str(ledger_id), "payment_method_id": str(payment_method_id), "category_id": str(category_id), "amount_cents": 1299, "memo": "Lunch", "transacted_at": "2026-10-18"}
    create_transaction.assert_called_once()
    assert create_transaction.call_args.kwargs["ledger_id"] == ledger_id
    assert create_transaction.call_args.kwargs["user_id"] == user_id
    assert create_transaction.call_args.kwargs["data"].amount_cents == 1299
    assert create_transaction.call_args.args == (db,)


def test_create_manual_transaction_rejects_nonmembers(monkeypatch) -> None:
    """가계부 멤버가 아니면 Service를 호출하지 않는다."""
    user_id, ledger_id = uuid4(), uuid4()
    create_transaction = Mock()
    monkeypatch.setattr(transactions_router, "create_manual_transaction", create_transaction)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/transactions", json={"payment_method_id": str(uuid4()), "category_id": str(uuid4()), "amount_cents": 1299, "transacted_at": "2026-10-18"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    create_transaction.assert_not_called()


def test_create_manual_transaction_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰이 없으면 거래 생성 Service를 호출하지 않는다."""
    create_transaction = Mock()
    monkeypatch.setattr(transactions_router, "create_manual_transaction", create_transaction)

    with TestClient(app) as client:
        response = client.post(f"/ledgers/{uuid4()}/transactions", json={"payment_method_id": str(uuid4()), "category_id": str(uuid4()), "amount_cents": 1299, "transacted_at": "2026-10-18"})

    assert response.status_code == 401
    create_transaction.assert_not_called()


def test_create_manual_transaction_rejects_nonpositive_amount(monkeypatch) -> None:
    """0원 지출은 요청 스키마에서 거부한다."""
    user_id, ledger_id = uuid4(), uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    create_transaction = Mock()
    monkeypatch.setattr(transactions_router, "create_manual_transaction", create_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: ledger
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/transactions", json={"payment_method_id": str(uuid4()), "category_id": str(uuid4()), "amount_cents": 0, "transacted_at": "2026-10-18"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    create_transaction.assert_not_called()
