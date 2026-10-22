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


def test_list_ledger_transactions_returns_expenses_in_requested_period(monkeypatch) -> None:
    """가계부 멤버는 기간별 지출 목록을 API에서 조회할 수 있다."""
    user_id, ledger_id = uuid4(), uuid4()
    payment_method_id, category_id = uuid4(), uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id, payment_method_id=payment_method_id, category_id=category_id, amount_cents=1299, transacted_at=date(2026, 10, 18), memo="Lunch")
    find_transactions = Mock(return_value=[transaction])
    db = Mock()
    monkeypatch.setattr(transactions_router, "list_ledger_transactions", find_transactions)
    app.dependency_overrides[get_user_ledger] = lambda: ledger
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.get(f"/ledgers/{ledger_id}/transactions", params={"start_date": "2026-10-01", "end_date": "2026-10-31"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [{"id": str(transaction.id), "ledger_id": str(ledger_id), "payment_method_id": str(payment_method_id), "category_id": str(category_id), "amount_cents": 1299, "transacted_at": "2026-10-18", "memo": "Lunch"}]
    find_transactions.assert_called_once_with(db, ledger_id=ledger_id, start_date=date(2026, 10, 1), end_date=date(2026, 10, 31))


def test_list_ledger_transactions_rejects_nonmembers(monkeypatch) -> None:
    """가계부 멤버가 아니면 지출 목록 Service를 호출하지 않는다."""
    user_id, ledger_id = uuid4(), uuid4()
    find_transactions = Mock()
    monkeypatch.setattr(transactions_router, "list_ledger_transactions", find_transactions)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.get(f"/ledgers/{ledger_id}/transactions", params={"start_date": "2026-10-01", "end_date": "2026-10-31"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    find_transactions.assert_not_called()


def test_list_ledger_transactions_requires_authentication(monkeypatch) -> None:
    """토큰이 없으면 지출 목록 Service를 호출하지 않는다."""
    find_transactions = Mock()
    monkeypatch.setattr(transactions_router, "list_ledger_transactions", find_transactions)

    with TestClient(app) as client:
        response = client.get(f"/ledgers/{uuid4()}/transactions", params={"start_date": "2026-10-01", "end_date": "2026-10-31"})

    assert response.status_code == 401
    find_transactions.assert_not_called()


def test_update_manual_transaction_returns_updated_expense(monkeypatch) -> None:
    """인증된 가계부 멤버는 수동 지출을 수정하고 변경된 값을 받는다."""
    user_id, ledger_id, transaction_id = uuid4(), uuid4(), uuid4()
    payment_method_id, category_id = uuid4(), uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    transaction = Transaction(id=transaction_id, ledger_id=ledger_id, payment_method_id=payment_method_id, category_id=category_id, amount_cents=2500, transacted_at=date(2026, 10, 20), memo=None, source="manual")
    update_transaction = Mock(return_value=transaction)
    db = Mock()
    monkeypatch.setattr(transactions_router, "update_manual_transaction", update_transaction)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: ledger
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.put(f"/ledgers/{ledger_id}/transactions/{transaction_id}", json={"payment_method_id": str(payment_method_id), "category_id": str(category_id), "amount_cents": 2500, "transacted_at": "2026-10-20"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == {"id": str(transaction_id), "ledger_id": str(ledger_id), "payment_method_id": str(payment_method_id), "category_id": str(category_id), "amount_cents": 2500, "transacted_at": "2026-10-20", "memo": None}
    update_transaction.assert_called_once()
    assert update_transaction.call_args.args == (db,)
    assert update_transaction.call_args.kwargs["ledger_id"] == ledger_id
    assert update_transaction.call_args.kwargs["transaction_id"] == transaction_id
    assert update_transaction.call_args.kwargs["user_id"] == user_id
    assert update_transaction.call_args.kwargs["data"].memo is None


def test_update_manual_transaction_rejects_nonmembers(monkeypatch) -> None:
    """가계부 멤버가 아니면 수정 Service를 호출하지 않는다."""
    user_id, ledger_id = uuid4(), uuid4()
    update_transaction = Mock()
    monkeypatch.setattr(transactions_router, "update_manual_transaction", update_transaction)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.put(f"/ledgers/{ledger_id}/transactions/{uuid4()}", json={"payment_method_id": str(uuid4()), "category_id": str(uuid4()), "amount_cents": 2500, "transacted_at": "2026-10-20"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    update_transaction.assert_not_called()


def test_update_manual_transaction_requires_authentication(monkeypatch) -> None:
    """토큰이 없으면 수동 지출을 수정하지 않는다."""
    update_transaction = Mock()
    monkeypatch.setattr(transactions_router, "update_manual_transaction", update_transaction)

    with TestClient(app) as client:
        response = client.put(f"/ledgers/{uuid4()}/transactions/{uuid4()}", json={"payment_method_id": str(uuid4()), "category_id": str(uuid4()), "amount_cents": 2500, "transacted_at": "2026-10-20"})

    assert response.status_code == 401
    update_transaction.assert_not_called()
