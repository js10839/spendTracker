from datetime import date
from unittest.mock import Mock
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers import repository as ledgers_repository
from app.ledgers.dependencies import get_user_ledger
from app.main import app
from app.transactions import router as transactions_router


def _group_response(ledger_id: UUID, payment_method_id: UUID, category_id: UUID, item_id: UUID) -> dict:
    """API 테스트에서 결제와 품목 응답을 같은 형식으로 사용한다."""
    return {"id": str(uuid4()), "ledger_id": str(ledger_id), "payment_method_id": str(payment_method_id), "merchant": "Cafe", "transacted_at": "2026-10-18", "memo": "Lunch", "source": "manual", "tax_cents": 100, "tip_cents": 200, "total_cents": 1599, "items": [{"id": str(item_id), "name": "Sandwich", "category_id": str(category_id), "amount_cents": 1299}]}


def _create_payload(payment_method_id: UUID, category_id: UUID, amount_cents: int = 1299) -> dict:
    """수동 결제 생성 요청에 품목과 결제 전체 금액을 포함한다."""
    return {"payment_method_id": str(payment_method_id), "merchant": "Cafe", "transacted_at": "2026-10-18", "memo": "Lunch", "tax_cents": 100, "tip_cents": 200, "items": [{"name": "Sandwich", "category_id": str(category_id), "amount_cents": amount_cents}]}


def test_create_transaction_returns_grouped_expense(monkeypatch) -> None:
    """가계부 멤버의 생성 요청은 품목과 계산된 합계를 반환한다."""
    user_id, ledger_id, payment_method_id, category_id, item_id = (uuid4() for _ in range(5))
    expected = _group_response(ledger_id, payment_method_id, category_id, item_id)
    create_transaction = Mock(return_value=expected)
    db = Mock()
    monkeypatch.setattr(transactions_router, "create_grouped_manual_transaction", create_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/transactions", json=_create_payload(payment_method_id, category_id))
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json() == expected
    create_transaction.assert_called_once()
    assert create_transaction.call_args.args == (db,)
    assert create_transaction.call_args.kwargs["ledger_id"] == ledger_id
    assert create_transaction.call_args.kwargs["user_id"] == user_id
    assert create_transaction.call_args.kwargs["data"].items[0].amount_cents == 1299


def test_create_transaction_rejects_nonmembers(monkeypatch) -> None:
    """가계부에 속하지 않은 사용자는 거래를 만들지 못한다."""
    user_id, ledger_id = uuid4(), uuid4()
    create_transaction = Mock()
    monkeypatch.setattr(transactions_router, "create_grouped_manual_transaction", create_transaction)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/transactions", json=_create_payload(uuid4(), uuid4()))
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    create_transaction.assert_not_called()


def test_create_transaction_rejects_nonpositive_item_amount(monkeypatch) -> None:
    """품목 금액이 0이면 Service 호출 전에 요청을 거부한다."""
    user_id, ledger_id = uuid4(), uuid4()
    create_transaction = Mock()
    monkeypatch.setattr(transactions_router, "create_grouped_manual_transaction", create_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(f"/ledgers/{ledger_id}/transactions", json=_create_payload(uuid4(), uuid4(), amount_cents=0))
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    create_transaction.assert_not_called()


def test_list_transactions_returns_grouped_expenses(monkeypatch) -> None:
    """기간 조회는 Service의 결제·품목 응답을 그대로 전달한다."""
    user_id, ledger_id, payment_method_id, category_id, item_id = (uuid4() for _ in range(5))
    expected = _group_response(ledger_id, payment_method_id, category_id, item_id)
    list_transactions = Mock(return_value=[expected])
    db = Mock()
    monkeypatch.setattr(transactions_router, "list_ledger_transactions", list_transactions)
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get(f"/ledgers/{ledger_id}/transactions", params={"start_date": "2026-10-01", "end_date": "2026-10-31"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [expected]
    list_transactions.assert_called_once_with(db, ledger_id=ledger_id, start_date=date(2026, 10, 1), end_date=date(2026, 10, 31))


def test_update_transaction_keeps_item_id(monkeypatch) -> None:
    """PUT 요청과 응답이 같은 기존 품목 ID를 사용한다."""
    user_id, ledger_id, payment_method_id, category_id, item_id = (uuid4() for _ in range(5))
    expected = _group_response(ledger_id, payment_method_id, category_id, item_id)
    transaction_id = UUID(expected["id"])
    update_transaction = Mock(return_value=expected)
    db = Mock()
    monkeypatch.setattr(transactions_router, "update_transaction_group", update_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    app.dependency_overrides[get_db] = lambda: db
    payload = _create_payload(payment_method_id, category_id)
    payload["items"][0]["id"] = str(item_id)

    try:
        with TestClient(app) as client:
            response = client.put(f"/ledgers/{ledger_id}/transactions/{transaction_id}", json=payload)
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == expected
    update_transaction.assert_called_once()
    assert update_transaction.call_args.kwargs["data"].items[0].id == item_id
    assert update_transaction.call_args.kwargs["transaction_id"] == transaction_id


def test_update_transaction_rejects_item_without_id(monkeypatch) -> None:
    """기존 품목 ID가 빠진 PUT 요청은 새 품목 생성으로 해석하지 않는다."""
    user_id, ledger_id = uuid4(), uuid4()
    update_transaction = Mock()
    monkeypatch.setattr(transactions_router, "update_transaction_group", update_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.put(f"/ledgers/{ledger_id}/transactions/{uuid4()}", json=_create_payload(uuid4(), uuid4()))
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422
    update_transaction.assert_not_called()


@pytest.mark.parametrize("method", ["get", "put"])
def test_transaction_read_and_update_reject_nonmembers(monkeypatch, method: str) -> None:
    """가계부 멤버가 아니면 조회와 수정 Service를 호출하지 않는다."""
    user_id, ledger_id = uuid4(), uuid4()
    list_transactions, update_transaction = Mock(), Mock()
    monkeypatch.setattr(transactions_router, "list_ledger_transactions", list_transactions)
    monkeypatch.setattr(transactions_router, "update_transaction_group", update_transaction)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            if method == "get":
                response = client.get(f"/ledgers/{ledger_id}/transactions", params={"start_date": "2026-10-01", "end_date": "2026-10-31"})
            else:
                payload = _create_payload(uuid4(), uuid4())
                payload["items"][0]["id"] = str(uuid4())
                response = client.put(f"/ledgers/{ledger_id}/transactions/{uuid4()}", json=payload)
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    list_transactions.assert_not_called()
    update_transaction.assert_not_called()


def test_transaction_routes_require_authentication(monkeypatch) -> None:
    """인증 없이 생성·조회·수정 Service에 접근하지 못한다."""
    create_transaction, list_transactions, update_transaction = Mock(), Mock(), Mock()
    monkeypatch.setattr(transactions_router, "create_grouped_manual_transaction", create_transaction)
    monkeypatch.setattr(transactions_router, "list_ledger_transactions", list_transactions)
    monkeypatch.setattr(transactions_router, "update_transaction_group", update_transaction)
    ledger_id = uuid4()
    with TestClient(app) as client:
        created = client.post(f"/ledgers/{ledger_id}/transactions", json=_create_payload(uuid4(), uuid4()))
        listed = client.get(f"/ledgers/{ledger_id}/transactions", params={"start_date": "2026-10-01", "end_date": "2026-10-31"})
        payload = _create_payload(uuid4(), uuid4())
        payload["items"][0]["id"] = str(uuid4())
        updated = client.put(f"/ledgers/{ledger_id}/transactions/{uuid4()}", json=payload)

    assert [created.status_code, listed.status_code, updated.status_code] == [401, 401, 401]
    create_transaction.assert_not_called()
    list_transactions.assert_not_called()
    update_transaction.assert_not_called()
