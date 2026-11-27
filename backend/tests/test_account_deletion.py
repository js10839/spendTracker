from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, Mock
from uuid import uuid4

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.dialects import postgresql
from sqlalchemy.engine import Connection
from sqlalchemy.exc import IntegrityError
from sqlalchemy.pool import StaticPool

from app.auth import admin
from app.auth.admin import AuthAdminUnavailable
from app.auth.dependencies import get_current_user_id
from app.db.session import get_db
from app.db.tables import (
    categories,
    income_records,
    income_sources,
    ledger_members,
    ledgers,
    metadata,
    payment_methods,
    transaction_items,
    transactions,
    users,
)
from app.main import app
from app.users import repository, retry_deletions, router, service


@pytest.fixture
def db(monkeypatch):
    """SQLite에서는 PostgreSQL 잠금을 대체하고 계정 삭제를 검증한다."""
    monkeypatch.setattr(repository, "lock_bootstrap", lambda db, user_id: None)
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with engine.begin() as connection:
        connection.exec_driver_sql("ATTACH DATABASE ':memory:' AS auth")
        connection.exec_driver_sql("PRAGMA foreign_keys=ON")
        metadata.create_all(connection)
    with engine.connect() as session:
        yield session
    engine.dispose()


def test_delete_app_data_keeps_other_user_and_records_pending_state(db: Connection) -> None:
    """삭제한 사용자의 데이터만 지우고 다른 사용자와 공통 카테고리를 보존한다."""
    user_id, other_id, ledger_id, other_ledger_id, method_id, transaction_id, category_id, source_id = (uuid4() for _ in range(8))
    db.execute(users.insert().values(id=user_id, nickname='Owner', plan='free'))
    db.execute(users.insert().values(id=other_id, nickname='Other', plan='free'))
    db.execute(categories.insert().values(id=category_id, name='Food'))
    db.execute(ledgers.insert().values(id=ledger_id, owner_user_id=user_id, name='Personal'))
    db.execute(ledgers.insert().values(id=other_ledger_id, owner_user_id=other_id, name='Other'))
    db.execute(payment_methods.insert().values(id=method_id, user_id=user_id, name='Cash', type='cash-like', color='#FCA05A'))
    db.execute(ledger_members.insert().values(ledger_id=ledger_id, user_id=user_id, role='owner'))
    db.execute(ledger_members.insert().values(ledger_id=other_ledger_id, user_id=other_id, role='owner'))
    db.execute(transactions.insert().values(id=transaction_id, ledger_id=ledger_id, payment_method_id=method_id, transacted_at=date(2026, 10, 1), total_cents=100, tax_cents=0, tip_cents=0, source='manual', deleted_at=datetime.now(UTC)))
    db.execute(income_sources.insert().values(id=source_id, ledger_id=ledger_id, expected_amount_cents=100, frequency='once', reference_date=date(2026, 10, 1), next_expected_date=date(2026, 10, 1)))
    db.execute(transaction_items.insert().values(transaction_id=transaction_id, category_id=category_id, name='Coffee', amount_cents=100))
    db.execute(income_records.insert().values(ledger_id=ledger_id, income_source_id=source_id, amount_cents=100, income_type='other', received_at=date(2026, 10, 1)))
    db.commit()

    service.delete_user_app_data(db, user_id)

    user = db.execute(select(users).where(users.c.id == user_id)).one_or_none()
    assert user is not None and user.nickname is None and user.deletion_requested_at is not None
    assert db.execute(select(ledgers).where(ledgers.c.id == ledger_id)).one_or_none() is None
    assert db.execute(select(payment_methods).where(payment_methods.c.id == method_id)).one_or_none() is None
    assert db.execute(select(transactions).where(transactions.c.id == transaction_id)).one_or_none() is None
    assert db.execute(select(transaction_items)).all() == []
    assert db.execute(select(income_records)).all() == []
    assert db.execute(select(income_sources)).all() == []
    assert db.execute(select(users).where(users.c.id == other_id)).one_or_none() is not None
    assert db.execute(select(ledgers).where(ledgers.c.id == other_ledger_id)).one_or_none() is not None
    assert db.execute(select(ledger_members).where(ledger_members.c.ledger_id == other_ledger_id, ledger_members.c.user_id == other_id)).one_or_none() is not None
    assert db.execute(select(categories).where(categories.c.id == category_id)).one_or_none() is not None


def test_delete_app_data_rolls_back_on_failure(db: Connection, monkeypatch) -> None:
    """중간 오류가 나면 삭제 상태와 기존 앱 데이터를 함께 되돌린다."""
    user_id, ledger_id = uuid4(), uuid4()
    db.execute(users.insert().values(id=user_id, nickname='Owner', plan='free'))
    db.execute(ledgers.insert().values(id=ledger_id, owner_user_id=user_id, name='Personal'))
    db.commit()
    monkeypatch.setattr(repository, "delete_ledger_income", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        service.delete_user_app_data(db, user_id)

    assert db.execute(select(users).where(users.c.id == user_id)).one_or_none().deletion_requested_at is None
    assert db.execute(select(users).where(users.c.id == user_id)).one_or_none().nickname == "Owner"
    assert db.execute(select(ledgers).where(ledgers.c.id == ledger_id)).one_or_none() is not None


def test_delete_before_bootstrap_creates_only_pending_profile(db: Connection) -> None:
    """초기화 전 계정도 가계부 생성 없이 삭제 진행 상태를 남긴다."""
    user_id = uuid4()
    service.delete_user_app_data(db, user_id)
    assert db.execute(select(users).where(users.c.id == user_id)).one_or_none().deletion_requested_at is not None
    assert db.execute(select(ledgers)).all() == []
    assert db.execute(select(payment_methods)).all() == []


def test_owned_ledger_with_another_member_is_not_deleted(db: Connection) -> None:
    """다른 멤버가 있는 가계부는 정책 결정 전 삭제하지 않고 롤백한다."""
    user_id, other_id, ledger_id = uuid4(), uuid4(), uuid4()
    db.execute(users.insert().values(id=user_id, plan='free'))
    db.execute(users.insert().values(id=other_id, plan='free'))
    db.execute(ledgers.insert().values(id=ledger_id, owner_user_id=user_id, name='Shared'))
    db.execute(ledger_members.insert().values(ledger_id=ledger_id, user_id=user_id, role='owner'))
    db.execute(ledger_members.insert().values(ledger_id=ledger_id, user_id=other_id, role='member'))
    db.commit()
    with pytest.raises(IntegrityError):
        service.delete_user_app_data(db, user_id)
    assert db.execute(select(ledgers).where(ledgers.c.id == ledger_id)).one_or_none() is not None
    assert db.execute(select(ledger_members).where(ledger_members.c.ledger_id == ledger_id, ledger_members.c.user_id == user_id)).one_or_none() is not None
    assert db.execute(select(users).where(users.c.id == user_id)).one_or_none().deletion_requested_at is None


@pytest.mark.parametrize("method,path,payload", [("get", "/users/me", None), ("post", "/users/me/bootstrap", None), ("get", "/ledgers", None), ("get", "/categories", None), ("post", "/users/me/payment-methods", {"name": "Visa", "type": "credit", "closing_day": 15, "color": "#123456"})])
def test_pending_account_cannot_use_regular_apis(db: Connection, method: str, path: str, payload: dict | None) -> None:
    """삭제 진행 중인 사용자는 일반 조회와 쓰기 API를 사용할 수 없다."""
    user_id = uuid4()
    db.execute(users.insert().values(id=user_id, plan='free', deletion_requested_at=datetime.now(UTC)))
    db.commit()
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db
    try:
        with TestClient(app) as client:
            response = client.request(method, path, json=payload)
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 409


def test_pending_user_can_retry_account_deletion(db: Connection, monkeypatch) -> None:
    """삭제 진행 중에도 계정 삭제 API는 다시 호출할 수 있다."""
    user_id = uuid4()
    db.execute(users.insert().values(id=user_id, plan='free', deletion_requested_at=datetime.now(UTC)))
    db.commit()
    delete_account = AsyncMock()
    monkeypatch.setattr(router, "delete_account", delete_account)
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: db
    try:
        with TestClient(app) as client:
            response = client.delete("/users/me")
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 204
    delete_account.assert_awaited_once_with(user_id)


@pytest.mark.asyncio
async def test_auth_failure_reports_retry_without_claiming_success(monkeypatch) -> None:
    """앱 삭제 후 Auth 요청이 실패하면 재시도가 필요한 오류를 반환한다."""
    user_id = uuid4()
    monkeypatch.setattr(service, "ensure_auth_admin_configured", Mock())
    monkeypatch.setattr(service, "auth_user_exists", AsyncMock(return_value=True))
    delete_data = AsyncMock()
    monkeypatch.setattr(service, "run_in_threadpool", delete_data)
    monkeypatch.setattr(service, "delete_auth_user", AsyncMock(side_effect=AuthAdminUnavailable("timeout")))
    with pytest.raises(HTTPException) as raised:
        await service.delete_account(user_id)
    assert raised.value.status_code == 503
    delete_data.assert_awaited_once_with(service.delete_user_app_data_on_connection, user_id)


@pytest.mark.asyncio
async def test_deleted_auth_user_does_not_recreate_profile(monkeypatch) -> None:
    """이미 삭제된 Auth 계정의 재시도는 앱 프로필을 만들지 않는다."""
    monkeypatch.setattr(service, "ensure_auth_admin_configured", Mock())
    monkeypatch.setattr(service, "auth_user_exists", AsyncMock(return_value=False))
    delete_data = AsyncMock()
    monkeypatch.setattr(service, "run_in_threadpool", delete_data)
    monkeypatch.setattr(service, "delete_auth_user", AsyncMock())
    await service.delete_account(uuid4())
    delete_data.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("status_code,payload,expected", [(200, {"id": "test"}, True), (404, {"error_code": "user_not_found"}, False)])
async def test_auth_user_lookup_interprets_supabase_response(monkeypatch, status_code: int, payload: dict, expected: bool) -> None:
    """관리자 조회는 사용자 존재와 명시적인 미존재 응답을 구분한다."""
    user_id = uuid4()
    monkeypatch.setattr(admin, "settings", SimpleNamespace(supabase_url="https://example.test", supabase_secret_key="test-secret"))
    original_client = httpx.AsyncClient

    def handler(request: httpx.Request) -> httpx.Response:
        """실제 인증 정보를 사용하지 않고 요청 경로와 키 헤더를 검사한다."""
        assert request.method == "GET"
        assert request.url.path == f"/auth/v1/admin/users/{user_id}"
        assert request.headers["apikey"] == "test-secret"
        return httpx.Response(status_code, json=payload)

    monkeypatch.setattr(admin.httpx, "AsyncClient", lambda **kwargs: original_client(transport=httpx.MockTransport(handler), **kwargs))
    assert await admin.auth_user_exists(user_id) is expected


@pytest.mark.asyncio
async def test_auth_lookup_does_not_treat_unknown_404_as_user_not_found(monkeypatch) -> None:
    """경로 오류 같은 다른 404 응답은 삭제 완료로 취급하지 않는다."""
    monkeypatch.setattr(admin, "settings", SimpleNamespace(supabase_url="https://example.test", supabase_secret_key="test-secret"))
    original_client = httpx.AsyncClient
    transport = httpx.MockTransport(lambda request: httpx.Response(404, json={"error_code": "other"}))
    monkeypatch.setattr(admin.httpx, "AsyncClient", lambda **kwargs: original_client(transport=transport, **kwargs))
    with pytest.raises(AuthAdminUnavailable):
        await admin.auth_user_exists(uuid4())


@pytest.mark.asyncio
@pytest.mark.parametrize("status_code,payload", [(204, None), (404, {"error_code": "user_not_found"})])
async def test_auth_delete_accepts_success_or_already_deleted(monkeypatch, status_code: int, payload: dict | None) -> None:
    """삭제 성공과 이미 삭제된 계정의 재시도는 모두 완료로 처리한다."""
    user_id = uuid4()
    monkeypatch.setattr(admin, "settings", SimpleNamespace(supabase_url="https://example.test", supabase_secret_key="test-secret"))
    original_client = httpx.AsyncClient

    def handler(request: httpx.Request) -> httpx.Response:
        """삭제 요청이 지정한 Auth 사용자에게 전송되는지 확인한다."""
        assert request.method == "DELETE"
        assert request.url.path == f"/auth/v1/admin/users/{user_id}"
        return httpx.Response(status_code, json=payload)

    monkeypatch.setattr(admin.httpx, "AsyncClient", lambda **kwargs: original_client(transport=httpx.MockTransport(handler), **kwargs))
    await admin.delete_auth_user(user_id)


@pytest.mark.asyncio
async def test_auth_admin_misconfiguration_does_not_delete_app_data(monkeypatch) -> None:
    """관리자 설정이 없으면 앱 데이터를 삭제하지 않는다."""
    monkeypatch.setattr(service, "ensure_auth_admin_configured", Mock(side_effect=AuthAdminUnavailable("not configured")))
    delete_data = AsyncMock()
    monkeypatch.setattr(service, "run_in_threadpool", delete_data)
    with pytest.raises(HTTPException) as raised:
        await service.delete_account(uuid4())
    assert raised.value.status_code == 503
    delete_data.assert_not_awaited()


@pytest.mark.asyncio
async def test_retry_command_continues_after_failed_account(monkeypatch) -> None:
    """재시도 중 일부 계정이 실패해도 나머지를 처리하고 실패를 알린다."""
    first_id, second_id = uuid4(), uuid4()
    db = Mock()
    session_context = MagicMock()
    session_context.__enter__.return_value = db
    monkeypatch.setattr(retry_deletions.engine, "connect", lambda: session_context)
    monkeypatch.setattr(repository, "list_pending_deletion_user_ids", Mock(return_value=[first_id, second_id]))
    delete_account = AsyncMock(side_effect=[HTTPException(status_code=503), None])
    monkeypatch.setattr(retry_deletions, "delete_account", delete_account)

    assert await retry_deletions.main() == 1
    assert delete_account.await_count == 2


def test_writes_use_postgresql_shared_lock(monkeypatch) -> None:
    """일반 쓰기는 공유 잠금, 계정 삭제는 배타 잠금으로 순서를 보장한다."""
    db = Mock()
    db.execute.return_value.one_or_none.return_value = None
    repository.lock_user_by_id(db, uuid4(), shared=True)
    shared = str(db.execute.call_args.args[0].compile(dialect=postgresql.dialect()))
    repository.lock_user_by_id(db, uuid4())
    exclusive = str(db.execute.call_args.args[0].compile(dialect=postgresql.dialect()))
    assert "FOR SHARE" in shared
    assert "FOR UPDATE" in exclusive
