from types import SimpleNamespace
from unittest.mock import ANY, Mock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.auth.dependencies import get_active_user_id, get_current_user_id
from app.db.session import get_db
from app.main import app
from app.payment_methods import repository, router, service
from app.payment_methods.schema import PaymentMethodCreate


@pytest.mark.parametrize(
    "data",
    [
        {"name": "Visa", "type": "credit", "color": "#123456"},
        {"name": "Visa", "type": "credit", "closing_day": 32, "color": "#123456"},
        {"name": "Cash", "type": "cash-like", "closing_day": 1, "color": "#123456"},
        {"name": "Cash", "type": "cash-like", "color": "#123456"},
    ],
)
def test_create_schema_rejects_invalid_closing_day(data: dict) -> None:
    """신용카드의 마감일 누락·범위 초과와 현금성 수단의 마감일 입력을 막는다."""
    with pytest.raises(ValidationError):
        PaymentMethodCreate.model_validate(data)


def test_repository_inserts_and_returns_row_without_committing() -> None:
    """Repository는 결제수단을 삽입하지만 트랜잭션을 확정하지 않는다."""
    db = Mock()
    user_id = uuid4()

    db.execute.return_value.one.return_value = SimpleNamespace(
        user_id=user_id, name="Visa", type="credit", closing_day=15, color="#123456"
    )
    payment_method = repository.add_payment_method(
        db, user_id, "Visa", "credit", 15, "#123456"
    )

    assert payment_method.user_id == user_id
    assert payment_method.type == "credit"
    assert payment_method.closing_day == 15
    statement = db.execute.call_args.args[0]
    assert statement.is_insert
    assert statement.compile().params == {
        "id": None, "user_id": user_id, "name": "Visa", "type": "credit",
        "closing_day": 15, "color": "#123456",
    }
    db.commit.assert_not_called()


def test_service_commits_after_adding_payment_method(monkeypatch) -> None:
    """Service는 Repository가 반환한 결제수단을 확정한다."""
    db = Mock()
    user_id = uuid4()
    data = PaymentMethodCreate(
        name="Visa", type="credit", closing_day=15, color="#123456"
    )
    payment_method = SimpleNamespace(user_id=user_id, name="Visa", type="credit", closing_day=15, color="#123456")
    add_payment_method = Mock(return_value=payment_method)
    monkeypatch.setattr(repository, "add_payment_method", add_payment_method)

    assert service.create_payment_method(db, user_id, data) is payment_method

    add_payment_method.assert_called_once_with(
        db,
        user_id=user_id,
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
    """인증된 사용자는 자신의 지갑에 결제수단을 생성하고 201 응답을 받는다."""
    user_id = uuid4()
    payment_method = SimpleNamespace(id=uuid4(), user_id=user_id, name="Visa", type="credit", closing_day=15, color="#123456")
    db = Mock()
    create_payment_method = Mock(return_value=payment_method)
    monkeypatch.setattr(router, "create_payment_method", create_payment_method)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db

    try:
        with TestClient(app) as client:
            response = client.post(
                "/users/me/payment-methods",
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
    assert create_payment_method.call_args.kwargs["user_id"] == user_id
    assert create_payment_method.call_args.args == (db,)


def test_create_api_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰 없는 요청은 결제수단 생성 Service를 호출하지 않는다."""
    create_payment_method = Mock()
    monkeypatch.setattr(router, "create_payment_method", create_payment_method)

    with TestClient(app) as client:
        response = client.post(
            "/users/me/payment-methods",
            json={"name": "Visa", "type": "credit", "closing_day": 15, "color": "#123456"},
        )

    assert response.status_code == 401
    create_payment_method.assert_not_called()


def test_list_api_returns_only_current_users_wallet(monkeypatch) -> None:
    """지갑 조회는 가계부 선택 없이 현재 사용자 ID로 조회한다."""
    user_id = uuid4()
    payment_method = SimpleNamespace(id=uuid4(), user_id=user_id, name="Visa", type="credit", closing_day=15, color="#123456")
    get_payment_methods = Mock(return_value=[payment_method])
    monkeypatch.setattr(router, "get_payment_methods", get_payment_methods)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.get("/users/me/payment-methods")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json() == [{"id": str(payment_method.id), "name": "Visa", "type": "credit", "closing_day": 15, "color": "#123456"}]
    get_payment_methods.assert_called_once_with(ANY, user_id)


def test_repository_lists_only_users_payment_methods() -> None:
    """Repository 조회 조건은 가계부 ID가 아닌 사용자 ID다."""
    db = Mock()
    user_id = uuid4()
    payment_method = SimpleNamespace(id=uuid4(), user_id=user_id, name="Visa", type="credit", closing_day=15, color="#123456")
    db.execute.return_value = [payment_method]

    assert repository.list_payment_methods(db, user_id) == [payment_method]
    assert db.execute.call_args.args[0].compile().params["user_id_1"] == user_id
    db.commit.assert_not_called()


def test_repository_finds_existing_cash_for_user() -> None:
    """기본 Cash 중복 생성을 막기 위해 사용자 소유의 현금 항목을 찾는다."""
    user_id = uuid4()
    cash = SimpleNamespace(closing_day=None, id=uuid4(), user_id=user_id, name="Cash", type="cash-like", color="#FCA05A")
    db = Mock()
    db.execute.return_value.one_or_none.return_value = cash

    assert repository.find_cash_payment_method(db, user_id) is cash
    statement = db.execute.call_args.args[0]
    assert "payment_methods.user_id =" in str(statement)
    assert "lower(payment_methods.name) =" in str(statement)
    assert user_id in statement.compile().params.values()
    db.commit.assert_not_called()


def test_service_lists_payment_methods_without_committing(monkeypatch) -> None:
    """지갑 조회 Service는 사용자 ID만 Repository에 전달하고 커밋하지 않는다."""
    db = Mock()
    user_id = uuid4()
    list_payment_methods = Mock(return_value=[])
    monkeypatch.setattr(repository, "list_payment_methods", list_payment_methods)

    assert service.get_payment_methods(db, user_id) == []
    list_payment_methods.assert_called_once_with(db, user_id)
    db.commit.assert_not_called()


def test_list_api_rejects_unauthenticated_requests(monkeypatch) -> None:
    """토큰 없이 지갑 목록을 조회할 수 없다."""
    get_payment_methods = Mock()
    monkeypatch.setattr(router, "get_payment_methods", get_payment_methods)

    with TestClient(app) as client:
        response = client.get("/users/me/payment-methods")

    assert response.status_code == 401
    get_payment_methods.assert_not_called()


def test_patch_color_rejects_builtin_cash(monkeypatch) -> None:
    """유효한 새 색상을 보내도 기본 Cash의 고정 색상은 유지한다."""
    user_id = uuid4()
    cash = SimpleNamespace(
        id=uuid4(), user_id=user_id, name="Cash", type="cash-like", closing_day=None, color="#FCA05A"
    )
    db = Mock()
    db.execute.return_value.one_or_none.return_value = cash
    monkeypatch.setitem(app.dependency_overrides, get_active_user_id, lambda: user_id)
    monkeypatch.setitem(app.dependency_overrides, get_db, lambda: db)

    with TestClient(app) as client:
        response = client.patch(
            f"/users/me/payment-methods/{cash.id}", json={"color": "#3366FF"}
        )

    assert response.status_code == 422
    assert response.json()["detail"] == "The default Cash color cannot be changed"
    assert cash.color == "#FCA05A"
    db.execute.assert_called_once()
    db.commit.assert_not_called()


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": None},
        {"name": "  "},
        {"closing_day": 0},
        {"closing_day": 32},
        {"closing_day": "12"},
        {"color": None},
        {"color": ""},
        {"color": "3366FF"},
        {"color": " #3366FF "},
        {"type": "cash-like"},
    ],
)
def test_patch_details_validates_payload(monkeypatch, payload) -> None:
    """빈 요청과 잘못된 수정 필드는 결제수단을 조회하기 전에 거절한다."""
    db = Mock()
    monkeypatch.setitem(app.dependency_overrides, get_active_user_id, uuid4)
    monkeypatch.setitem(app.dependency_overrides, get_db, lambda: db)
    with TestClient(app) as client:
        response = client.patch(f"/users/me/payment-methods/{uuid4()}", json=payload)
    assert response.status_code == 422
    db.execute.assert_not_called()


def test_patch_details_requires_authentication() -> None:
    """토큰 없이 결제수단 이름을 변경할 수 없다."""
    with TestClient(app) as client:
        response = client.patch(
            f"/users/me/payment-methods/{uuid4()}", json={"name": "New name"}
        )
    assert response.status_code == 401
