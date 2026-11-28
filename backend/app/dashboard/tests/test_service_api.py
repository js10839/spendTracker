from datetime import UTC, date, datetime, timedelta
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.auth.dependencies import get_active_user_id
from app.dashboard import router, service
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.integrations.bankday import BankdayUnavailable
from app.ledgers.dependencies import get_user_ledger
from app.main import app


def test_fresh_holiday_cache_skips_provider(monkeypatch):
    year = datetime.now(UTC).year
    monkeypatch.setattr(
        service.repository,
        "find_bank_year",
        Mock(
            return_value={
                "year": year,
                "fetched_at": datetime.now(UTC),
            }
        ),
    )
    fetch = Mock()
    monkeypatch.setattr(service, "fetch_bank_holidays", fetch)
    service.ensure_bank_year(Mock(), year)
    fetch.assert_not_called()


def test_stale_holiday_cache_is_refreshed(monkeypatch):
    year = datetime.now(UTC).year
    monkeypatch.setattr(
        service.repository,
        "find_bank_year",
        Mock(
            return_value={
                "year": year,
                "fetched_at": datetime.now(UTC) - timedelta(days=31),
            }
        ),
    )
    holidays = {date(year, 1, 1)}
    monkeypatch.setattr(service, "fetch_bank_holidays", Mock(return_value=holidays))
    upsert = Mock()
    monkeypatch.setattr(service.repository, "upsert_bank_year", upsert)
    connection = Mock()
    service.ensure_bank_year(connection, year)
    assert upsert.call_args.args[:3] == (connection, year, holidays)


@pytest.mark.parametrize(
    "cached", [None, {"year": 2026, "fetched_at": datetime(2000, 1, 1, tzinfo=UTC)}]
)
def test_unavailable_holidays_preserve_cache_or_unadjusted_fallback(
    monkeypatch, cached
):
    year = datetime.now(UTC).year
    monkeypatch.setattr(service.repository, "find_bank_year", Mock(return_value=cached))
    monkeypatch.setattr(
        service, "fetch_bank_holidays", Mock(side_effect=BankdayUnavailable("offline"))
    )
    upsert = Mock()
    monkeypatch.setattr(service.repository, "upsert_bank_year", upsert)
    service.ensure_bank_year(Mock(), year)
    upsert.assert_not_called()


@pytest.mark.parametrize(
    "params",
    [
        {"as_of": date(1, 1, 1)},
        {"as_of": date(9998, 1, 1)},
        {"month": date(1, 1, 1)},
        {"year": 0},
        {"year": 9998},
        {"category_start": date(2026, 1, 1)},
        {"category_end": date(2026, 1, 1)},
        {"category_start": date(2026, 2, 1), "category_end": date(2026, 1, 1)},
        {"category_start": date(2025, 1, 1), "category_end": date(2026, 1, 2)},
    ],
)
def test_invalid_selections_do_not_query_database(params):
    connection = Mock()
    with pytest.raises(HTTPException) as error:
        service._read_dashboard(
            connection,
            **{
                "ledger_id": uuid4(),
                "user_id": uuid4(),
                "as_of": date(2026, 11, 13),
                **params,
            },
        )
    assert error.value.status_code == 422
    connection.execute.assert_not_called()


def test_unknown_or_unowned_card_is_404(monkeypatch):
    monkeypatch.setattr(service, "find_card", Mock(return_value=None))
    spending = Mock()
    monkeypatch.setattr(service.repository, "read_spending", spending)
    with pytest.raises(HTTPException) as error:
        service._read_dashboard(
            Mock(),
            ledger_id=uuid4(),
            user_id=uuid4(),
            as_of=date(2026, 11, 13),
            payment_method_id=uuid4(),
        )
    assert error.value.status_code == 404
    spending.assert_not_called()


def test_mixed_currency_is_rejected_before_cache_writes(monkeypatch):
    monkeypatch.setattr(
        service.repository,
        "read_spending",
        Mock(return_value={"unsupported_currency": True}),
    )
    cache = Mock()
    monkeypatch.setattr(service, "ensure_bank_year", cache)
    with pytest.raises(HTTPException) as error:
        service._read_dashboard(
            Mock(), ledger_id=uuid4(), user_id=uuid4(), as_of=date(2026, 11, 13)
        )
    assert error.value.status_code == 422
    cache.assert_not_called()


def test_success_commits_and_failure_rolls_back(monkeypatch):
    db = Mock()
    result = object()
    read = Mock(return_value=result)
    monkeypatch.setattr(service, "_read_dashboard", read)
    assert service.read_dashboard(db, as_of=date(2026, 11, 13)) is result
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()
    db.reset_mock()
    read.side_effect = RuntimeError("query failed")
    with pytest.raises(RuntimeError, match="query failed"):
        service.read_dashboard(db)
    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


@pytest.fixture
def client(monkeypatch):
    user, ledger = uuid4(), uuid4()
    original = app.dependency_overrides.copy()
    app.dependency_overrides[get_active_user_id] = lambda: user
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(
        id=ledger, owner_user_id=user, name="Personal"
    )
    app.dependency_overrides[get_db] = lambda: Mock()
    read = Mock()
    monkeypatch.setattr(router, "read_dashboard", read)
    try:
        with TestClient(app, raise_server_exceptions=False) as test_client:
            yield test_client, read, user, ledger
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original)


@pytest.mark.parametrize(
    "query",
    [
        "",
        "?as_of=bad",
        "?as_of=2026-11-13&year=10000",
        "?as_of=2026-11-13&payment_method_id=not-a-uuid",
    ],
)
def test_invalid_request_rejected_before_service(client, query):
    http, read, _, ledger = client
    assert http.get(f"/ledgers/{ledger}/dashboard{query}").status_code == 422
    read.assert_not_called()


def test_route_forwards_typed_selections(client):
    http, read, user, ledger = client
    # A deliberate service error lets us inspect forwarding without mocking the
    # entire chart response or weakening FastAPI response validation.
    read.side_effect = HTTPException(404, "Credit card not found")
    card = uuid4()
    response = http.get(
        f"/ledgers/{ledger}/dashboard",
        params={
            "as_of": "2026-11-13",
            "month": "2026-10-01",
            "year": 2025,
            "payment_method_id": str(card),
            "category_start": "2026-10-02",
            "category_end": "2026-10-31",
        },
    )
    assert response.status_code == 404
    call = read.call_args.kwargs
    assert call == {
        "ledger_id": ledger,
        "user_id": user,
        "as_of": date(2026, 11, 13),
        "month": date(2026, 10, 1),
        "year": 2025,
        "payment_method_id": card,
        "category_start": date(2026, 10, 2),
        "category_end": date(2026, 10, 31),
    }


def test_authentication_required():
    with TestClient(app) as http:
        response = http.get(f"/ledgers/{uuid4()}/dashboard?as_of=2026-11-13")
    assert response.status_code == 401


def test_ledger_permission_failure_propagates(client):
    http, read, _, ledger = client

    def denied():
        raise HTTPException(403, "Ledger access denied")

    app.dependency_overrides[get_user_ledger] = denied
    assert http.get(f"/ledgers/{ledger}/dashboard?as_of=2026-11-13").status_code == 403
    read.assert_not_called()
