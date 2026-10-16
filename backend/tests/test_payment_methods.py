from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.models.payment_method import PaymentMethod
from app.db.session import get_db
from app.ledgers import repository as ledgers_repository
from app.main import app
from app.payment_methods import repository, router, service
from app.payment_methods.schema import PaymentMethodCreate


@pytest.mark.parametrize(
    "data",
    [
        {"name": "Visa", "type": "credit", "color": "#123456"},
        {"name": "Visa", "type": "credit", "closing_day": 32, "color": "#123456"},
        {"name": "Cash", "type": "cash-like", "closing_day": 1, "color": "#123456"},
    ],
)
def test_create_schema_rejects_invalid_closing_day(data: dict) -> None:
    """신용카드의 마감일 누락·범위 초과와 현금성 수단의 마감일 입력을 막는다."""
    with pytest.raises(ValidationError):
        PaymentMethodCreate.model_validate(data)


def test_repository_adds_and_flushes_without_committing() -> None:
    """Repository는 결제수단을 세션에 추가하지만 트랜잭션을 확정하지 않는다."""
    db = Mock()
    ledger_id = uuid4()

    payment_method = repository.add_payment_method(
        db, ledger_id, "Visa", "credit", 15, "#123456"
    )

    assert isinstance(payment_method, PaymentMethod)
    assert payment_method.ledger_id == ledger_id
    assert payment_method.type == "credit"
    assert payment_method.closing_day == 15
    db.add.assert_called_once_with(payment_method)
    db.flush.assert_called_once_with()
    db.commit.assert_not_called()


def test_service_commits_after_adding_payment_method(monkeypatch) -> None:
    """Service는 Repository가 반환한 결제수단을 확정한다."""
    db = Mock()
    ledger_id = uuid4()
    data = PaymentMethodCreate(
        name="Visa", type="credit", closing_day=15, color="#123456"
    )
    payment_method = PaymentMethod(ledger_id=ledger_id, name="Visa", type="credit", closing_day=15, color="#123456")
    add_payment_method = Mock(return_value=payment_method)
    monkeypatch.setattr(repository, "add_payment_method", add_payment_method)

    assert service.create_payment_method(db, ledger_id, data) is payment_method

    add_payment_method.assert_called_once_with(
        db,
        ledger_id=ledger_id,
        name="Visa",
        method_type="credit",
        closing_day=15,
        color="#123456",
    )
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_service_rolls_back_when_repository_fails(monkeypatch) -> None:
    """저장 중 오류가 나면 Service가 롤백하고 원래 오류를 전달한다."""
    db = Mock()
    data = PaymentMethodCreate(
        name="Visa", type="credit", closing_day=15, color="#123456"
    )
    monkeypatch.setattr(
        repository, "add_payment_method", Mock(side_effect=RuntimeError("DB error"))
    )

    with pytest.raises(RuntimeError, match="DB error"):
        service.create_payment_method(db, uuid4(), data)

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_create_api_returns_created_payment_method(monkeypatch) -> None:
    """가계부 멤버는 검증된 결제수단을 생성하고 201 응답을 받는다."""
    user_id = uuid4()
    ledger_id = uuid4()
    ledger = Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    payment_method = PaymentMethod(id=uuid4(), ledger_id=ledger_id, name="Visa", type="credit", closing_day=15, color="#123456")
    db = Mock()
    create_payment_method = Mock(return_value=payment_method)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=ledger))
    monkeypatch.setattr(router, "create_payment_method", create_payment_method)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.post(
                f"/ledgers/{ledger_id}/payment_methods",
                json={"name": "Visa", "type": "credit", "closing_day": 15, "color": "#123456"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 201
    assert response.json() == {
        "id": str(payment_method.id),
        "name": "Visa",
        "type": "credit",
        "closing_day": 15,
        "color": "#123456",
    }
    assert create_payment_method.call_args.kwargs["ledger_id"] == ledger_id
    assert create_payment_method.call_args.args == (db,)


def test_create_api_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰 없는 요청은 결제수단 생성 Service를 호출하지 않는다."""
    create_payment_method = Mock()
    monkeypatch.setattr(router, "create_payment_method", create_payment_method)

    with TestClient(app) as client:
        response = client.post(
            f"/ledgers/{uuid4()}/payment_methods",
            json={"name": "Visa", "type": "credit", "closing_day": 15, "color": "#123456"},
        )

    assert response.status_code == 401
    create_payment_method.assert_not_called()


def test_create_api_rejects_nonmembers(monkeypatch) -> None:
    """가계부 멤버가 아니면 결제수단 생성 Service를 호출하지 않는다."""
    user_id = uuid4()
    ledger_id = uuid4()
    create_payment_method = Mock()
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    monkeypatch.setattr(router, "create_payment_method", create_payment_method)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.post(
                f"/ledgers/{ledger_id}/payment_methods",
                json={"name": "Visa", "type": "credit", "closing_day": 15, "color": "#123456"},
            )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    create_payment_method.assert_not_called()
