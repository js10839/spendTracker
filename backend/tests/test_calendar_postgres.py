"""실제 PostgreSQL에서 실행별 스키마와 테스트별 트랜잭션으로 달력을 검증한다."""

import os
from datetime import UTC, date, datetime
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, insert, text
from sqlalchemy.orm import Session
from sqlalchemy.schema import CreateSchema, DropSchema

from app.auth.dependencies import get_current_user_id
from app.calendar import repository, service
from app.calendar.service import _read_calendar as read_calendar
from app.core.config import settings
from app.db.base import Base
from app.db.models import (
    BankCalendarYear,
    Category,
    IncomeRecord,
    IncomeSource,
    Ledger,
    LedgerMember,
    PaymentMethod,
    Transaction,
    TransactionItem,
    User,
)
from app.db.models.user import auth_users
from app.db.session import get_db
from app.main import app


@pytest.fixture(scope="module")
def calendar_engine():
    url = os.environ.get("CALENDAR_TEST_DB_URL")
    if not url and os.environ.get("CALENDAR_TEST_USE_CONFIGURED_DB") == "1":
        url = settings.db_url
    if not url:
        pytest.skip(
            "Set CALENDAR_TEST_DB_URL to run PostgreSQL calendar integration tests"
        )
    engine = create_engine(url, connect_args={"connect_timeout": 10})
    schema = f"calendar_test_{uuid4().hex}"
    auth_schema = f"{schema}_auth"
    with engine.begin() as conn:
        conn.execute(CreateSchema(schema))
        conn.execute(CreateSchema(auth_schema))
    isolated = engine.execution_options(
        schema_translate_map={None: schema, "auth": auth_schema}
    )
    try:
        Base.metadata.create_all(isolated)
        yield isolated
    finally:
        # 이번 실행에서 만든 두 스키마만 정리한다.
        with engine.begin() as conn:
            conn.execute(DropSchema(schema, cascade=True))
            conn.execute(DropSchema(auth_schema, cascade=True))
        engine.dispose()


@pytest.fixture
def db(calendar_engine, monkeypatch):
    # Bankday is deterministic here; API cache failure is tested separately.
    monkeypatch.setattr(service, "fetch_bank_holidays", lambda year: set())
    with calendar_engine.connect() as conn:
        transaction = conn.begin()
        # Raw SQL does not honor SQLAlchemy's schema_translate_map. Keep its
        # unqualified table names inside the same isolated test schema as ORM setup.
        schema = calendar_engine.get_execution_options()["schema_translate_map"][None]
        conn.execute(
            text("SELECT set_config('search_path', :schema, true)"), {"schema": schema}
        )
        assert conn.scalar(text("SELECT current_schema()")) == schema
        try:
            yield conn
        finally:
            transaction.rollback()


@pytest.fixture
def data(db):
    # 각 테스트에서 독립적인 사용자·가계부·결제수단을 생성한다.
    user, other, ledger, other_ledger, card, second, cash, foreign, category = (
        uuid4() for _ in range(9)
    )
    db.execute(insert(auth_users), [{"id": user}, {"id": other}])
    db.execute(insert(User.__table__), [{"id": user}, {"id": other}])
    db.execute(
        insert(Ledger.__table__),
        [
            {"id": ledger, "owner_user_id": user, "name": "Mine"},
            {"id": other_ledger, "owner_user_id": other, "name": "Other"},
        ],
    )
    db.execute(
        insert(LedgerMember.__table__),
        {"ledger_id": ledger, "user_id": user, "role": "owner"},
    )
    db.execute(
        insert(PaymentMethod.__table__),
        [
            {
                "id": card,
                "user_id": user,
                "name": "Chase",
                "type": "credit",
                "closing_day": 12,
                "color": "#3366FF",
            },
            {
                "id": second,
                "user_id": user,
                "name": "Other card",
                "type": "credit",
                "closing_day": 31,
                "color": "#FF3300",
            },
            {
                "id": cash,
                "user_id": user,
                "name": "Cash",
                "type": "cash-like",
                "closing_day": None,
                "color": "#999999",
            },
            {
                "id": foreign,
                "user_id": other,
                "name": "Foreign",
                "type": "credit",
                "closing_day": 8,
                "color": "#000000",
            },
        ],
    )
    db.execute(insert(Category.__table__), {"id": category, "name": "Food"})
    return {
        "user": user,
        "other": other,
        "ledger": ledger,
        "other_ledger": other_ledger,
        "card": card,
        "second": second,
        "cash": cash,
        "foreign": foreign,
        "category": category,
    }


def seed_insert(db, table, values):
    """시나리오의 행을 추가하고 다른 테스트 데이터에서 참조할 ID를 반환한다."""
    identifier = uuid4()
    db.execute(insert(table), {"id": identifier, **values})
    return identifier


def transaction(
    db, data, day, amount=100, method=None, ledger=None, deleted=False, item_count=0
):
    identifier = seed_insert(
        db,
        Transaction.__table__,
        {
            "ledger_id": ledger or data["ledger"],
            "payment_method_id": method or data["card"],
            "transacted_at": date.fromisoformat(day),
            "merchant": "Shop",
            "memo": "Receipt note",
            "total_cents": amount,
            "tax_cents": 10,
            "tip_cents": 20,
            "deleted_at": datetime.now(UTC) if deleted else None,
        },
    )
    for index in range(item_count):
        seed_insert(
            db,
            TransactionItem.__table__,
            {
                "transaction_id": identifier,
                "name": f"Item {index}",
                "category_id": data["category"],
                "amount_cents": 40,
            },
        )
    return identifier


def plan(
    db,
    data,
    expected,
    frequency="once",
    reference=None,
    income_type="paycheck",
    **extra,
):
    identifier = seed_insert(
        db,
        IncomeSource.__table__,
        {
            "ledger_id": data["ledger"],
            "income_type": income_type,
            "from_name": "Employer",
            "expected_amount_cents": 1000,
            "frequency": frequency,
            "reference_date": date.fromisoformat(reference or expected),
            "next_expected_date": date.fromisoformat(expected),
            **extra,
        },
    )
    return identifier


@pytest.mark.parametrize("closing", [None, 1, 12, 28, 29, 30, 31])
def test_periods_partition_dates_and_navigation(db, closing):
    # Batch leap February, ordinary February and New Year, including
    # anchor-on-close, using the same raw period SQL as the endpoint.
    from calendar import monthrange

    anchors = [
        date(year, month, day)
        for year, month in [(2024, 2), (2025, 2), (2026, 12)]
        for day in range(1, monthrange(year, month)[1] + 1)
    ]
    values = ", ".join(f"(CAST(:anchor_{i} AS date), {i})" for i in range(len(anchors)))
    period_sql = repository.PERIOD_SQL.replace(":anchor_date", "a.anchor_date")
    rows = (
        db.execute(
            text(
                f"WITH anchors(anchor_date, ordinal) AS (VALUES {values}) "
                f"SELECT bounds.* FROM anchors a CROSS JOIN LATERAL ({period_sql}) bounds "
                "ORDER BY a.ordinal"
            ),
            {
                "closing_day": closing,
                **{f"anchor_{i}": day for i, day in enumerate(anchors)},
            },
        )
        .mappings()
        .all()
    )
    for anchor, row in zip(anchors, rows, strict=True):
        start, end = row["start_date"], row["end_date"]
        assert start <= anchor <= end
        assert (row["next_anchor_date"] - end).days == 1
        assert (start - row["previous_anchor_date"]).days == 1
        if closing is None:
            assert start.day == 1
            assert end.day == monthrange(end.year, end.month)[1]
        else:
            assert end.day == min(closing, monthrange(end.year, end.month)[1])


def test_full_day_items_dots_totals_and_empty_days(db, data):
    transaction(db, data, "2026-11-06", amount=130, item_count=2)
    transaction(db, data, "2026-11-06", amount=-30)
    transaction(db, data, "2026-11-06", amount=200, method=data["cash"])
    transaction(db, data, "2026-11-06", amount=999, deleted=True)
    transaction(db, data, "2026-10-31", amount=999)
    transaction(db, data, "2026-12-01", amount=999)
    transaction(db, data, "2026-11-06", amount=999, ledger=data["other_ledger"])
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 11, 6))
    assert len(result.days) == 30
    assert {card.id for card in result.cards} == {data["card"], data["second"]}
    day = result.days[5]
    assert len(day.transactions) == 3
    assert (
        day.spending_cents == 300
    )  # Not multiplied by items, nor tax/tip added twice.
    assert sum(len(tx.items) for tx in day.transactions) == 2
    assert (
        next(tx for tx in day.transactions if tx.items).items[0].category_id
        == data["category"]
    )
    assert sorted(dot.transaction_count for dot in day.dots) == [1, 2]
    assert (
        next(dot for dot in day.dots if dot.payment_method_id == data["card"]).color
        == "#3366FF"
    )
    assert result.days[0].transactions == []
    assert result.days[0].spending_cents == 0


def test_card_filter_hides_other_closings_and_general_income(db, data):
    transaction(db, data, "2026-10-13")
    transaction(db, data, "2026-11-12")
    transaction(db, data, "2026-11-13")
    transaction(db, data, "2026-11-06", method=data["second"])
    seed_insert(
        db,
        IncomeRecord.__table__,
        {
            "ledger_id": data["ledger"],
            "income_type": "other",
            "amount_cents": 500,
            "received_at": date(2026, 10, 31),
            "payment_method_id": data["second"],
        },
    )
    result = read_calendar(
        db, data["ledger"], data["user"], date(2026, 11, 6), data["card"]
    )
    assert (result.start_date, result.end_date) == (
        date(2026, 10, 13),
        date(2026, 11, 12),
    )
    assert sum(len(day.transactions) for day in result.days) == 2
    day = next(day for day in result.days if day.date == date(2026, 10, 31))
    assert day.income == []
    assert day.received_income_cents == 0
    assert day.closing_cards == []
    assert [card.id for card in result.days[-1].closing_cards] == [data["card"]]
    following = read_calendar(
        db, data["ledger"], data["user"], result.next_anchor_date, data["card"]
    )
    assert following.start_date == date(2026, 11, 13)
    assert sum(len(day.transactions) for day in following.days) == 1


@pytest.mark.parametrize("selected", [None, "card", "second"])
def test_closing_indicators_follow_card_selection(db, data, selected):
    # February clamps the second card's 31st to the actual month-end. Filtering
    # must not remove the card from the dropdown or hide the selected closing.
    result = read_calendar(
        db,
        data["ledger"],
        data["user"],
        date(2026, 2, 6),
        data[selected] if selected else None,
    )
    closings = [
        (day.date, card.id) for day in result.days for card in day.closing_cards
    ]
    if selected == "card":
        assert closings == [(date(2026, 2, 12), data["card"])]
    elif selected == "second":
        assert closings == [(date(2026, 2, 28), data["second"])]
    else:
        assert closings == [
            (date(2026, 2, 12), data["card"]),
            (date(2026, 2, 28), data["second"]),
        ]
    assert {card.id for card in result.cards} == {data["card"], data["second"]}


@pytest.mark.parametrize("selected", [None, "card"])
def test_income_filter_matches_type_card_and_status(db, data, monkeypatch, selected):
    from unittest.mock import Mock

    entries = [
        ("paycheck", None, 100),
        ("cashback", data["card"], 200),
        ("cashback", data["second"], 300),
        ("other", None, 400),
        # A payment-method link alone must not turn Other into Cashback.
        ("other", data["card"], 500),
    ]
    for income_type, method, amount in entries:
        plan(
            db,
            data,
            "2026-11-06",
            income_type=income_type,
            payment_method_id=method,
            expected_amount_cents=amount,
        )
        seed_insert(
            db,
            IncomeRecord.__table__,
            {
                "ledger_id": data["ledger"],
                "income_type": income_type,
                "payment_method_id": method,
                "amount_cents": amount,
                "received_at": date(2026, 11, 6),
            },
        )
    # Matching cashback must still obey date, ledger and deletion restrictions.
    for extra in [
        {"ledger_id": data["other_ledger"]},
        {"received_at": date(2027, 1, 1)},
        {"deleted_at": datetime.now(UTC)},
    ]:
        seed_insert(
            db,
            IncomeRecord.__table__,
            {
                "ledger_id": data["ledger"],
                "income_type": "cashback",
                "payment_method_id": data["card"],
                "amount_cents": 999,
                "received_at": date(2026, 11, 6),
                **extra,
            },
        )
    holiday_fetch = Mock(return_value=set())
    monkeypatch.setattr(service, "fetch_bank_holidays", holiday_fetch)
    result = read_calendar(
        db,
        data["ledger"],
        data["user"],
        date(2026, 11, 6),
        data[selected] if selected else None,
    )
    day = next(day for day in result.days if day.date == date(2026, 11, 6))
    if selected:
        assert len(day.income) == 2
        assert {entry.status for entry in day.income} == {"planned", "received"}
        assert all(
            entry.income_type == "cashback" and entry.payment_method_id == data["card"]
            for entry in day.income
        )
        assert day.received_income_cents == 200
        holiday_fetch.assert_not_called()
    else:
        assert len(day.income) == 10
        assert {entry.income_type for entry in day.income} == {
            "paycheck",
            "cashback",
            "other",
        }
        assert day.received_income_cents == 1500


@pytest.mark.parametrize("selected", [None, "card", "cash"])
def test_calendar_unqualified_tables_with_recursive_ctes(db, data, selected):
    """스키마 없는 테이블 이름을 쓰는 실제 요청에서도 달력을 조회한다."""
    transaction(db, data, "2026-11-06", amount=200, method=data["cash"])
    transaction(db, data, "2026-11-06", amount=300, method=data["card"])
    schema_map = db.get_execution_options()["schema_translate_map"]
    db.execute(
        text("SELECT set_config('search_path', :schema, true)"),
        {"schema": schema_map[None]},
    )
    db.execution_options(schema_translate_map=None)

    with Session(bind=db, join_transaction_mode="create_savepoint") as session:
        app.dependency_overrides[get_db] = lambda: session
        app.dependency_overrides[get_current_user_id] = lambda: data["user"]
        try:
            with TestClient(app) as client:
                params = {"anchor_date": "2026-11-06"}
                if selected:
                    params["payment_method_id"] = str(data[selected])
                response = client.get(
                    f"/ledgers/{data['ledger']}/calendar", params=params
                )
                assert response.status_code == 200
                body = response.json()
                assert body["mode"] == (selected or "all")
                day = next(day for day in body["days"] if day["date"] == "2026-11-06")
                assert (
                    day["spending_cents"]
                    == {None: 500, "card": 300, "cash": 200}[selected]
                )
                assert len(day["transactions"]) == (2 if selected is None else 1)
        finally:
            app.dependency_overrides.clear()


def test_cash_calendar_filters_transactions_and_hides_income(db, data):
    """Cash는 월별 거래만 보여주고 모든 수입과 마감일을 숨긴다."""
    transaction(db, data, "2026-11-06", amount=200, method=data["cash"])
    transaction(db, data, "2026-11-06", amount=300, method=data["card"])
    transaction(db, data, "2026-10-31", method=data["cash"])
    transaction(db, data, "2026-11-06", method=data["cash"], deleted=True)
    transaction(
        db, data, "2026-11-06", method=data["cash"], ledger=data["other_ledger"]
    )
    for income_type, method in [("paycheck", None), ("cashback", data["cash"])]:
        plan(db, data, "2026-11-06", income_type=income_type, payment_method_id=method)
        seed_insert(
            db,
            IncomeRecord.__table__,
            {
                "ledger_id": data["ledger"],
                "income_type": income_type,
                "payment_method_id": method,
                "amount_cents": 100,
                "received_at": date(2026, 11, 6),
            },
        )

    result = read_calendar(
        db, data["ledger"], data["user"], date(2026, 11, 6), data["cash"]
    )
    assert result.mode == "cash"
    assert result.payment_method_id == data["cash"]
    assert (result.start_date, result.end_date) == (
        date(2026, 11, 1),
        date(2026, 11, 30),
    )
    assert len(result.days) == 30
    day = result.days[5]
    assert [item.payment_method_id for item in day.transactions] == [data["cash"]]
    assert day.spending_cents == 200
    assert all(
        not day.income and day.received_income_cents == 0 and not day.closing_cards
        for day in result.days
    )


@pytest.mark.parametrize("kind", ["foreign", "missing"])
def test_invalid_selected_payment_method_is_404(db, data, kind):
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as error:
        read_calendar(
            db, data["ledger"], data["user"], date(2026, 11, 6), data.get(kind, uuid4())
        )
    assert error.value.status_code == 404


def test_missing_wallet_metadata_does_not_drop_transaction(db, data):
    transaction(db, data, "2026-11-06", method=data["foreign"])
    day = read_calendar(db, data["ledger"], data["user"], date(2026, 11, 6)).days[5]
    assert len(day.transactions) == 1
    assert day.dots[0].label == "Unknown payment method"
    assert day.dots[0].color is None


def test_recurring_income_holiday_boundary_and_deleted_records(db, data, monkeypatch):
    monkeypatch.setattr(
        service,
        "fetch_bank_holidays",
        lambda year: {date(2026, 11, 2)} if year == 2026 else set(),
    )
    # Sunday Nov 1 and holiday Monday Nov 2 both shift into October.
    plan(db, data, "2026-11-01")
    plan(db, data, "2026-11-02")
    plan(db, data, "2020-01-31", "monthly")
    plan(db, data, "2020-01-03", "biweekly")
    plan(db, data, "2026-10-15", is_active=False)
    plan(db, data, "2026-10-15", deleted_at=datetime.now(UTC))
    for deleted in [None, datetime.now(UTC)]:
        seed_insert(
            db,
            IncomeRecord.__table__,
            {
                "ledger_id": data["ledger"],
                "income_type": "other",
                "amount_cents": 500,
                "received_at": date(2026, 10, 30),
                "deleted_at": deleted,
            },
        )
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 10, 6))
    day = result.days[29]
    assert day.received_income_cents == 500
    assert {entry.expected_date for entry in day.income} >= {
        date(2026, 11, 1),
        date(2026, 11, 2),
        date(2026, 10, 31),
    }
    entries = [
        entry
        for day in result.days
        for entry in day.income
        if entry.status == "planned"
    ]
    assert all(entry.display_date.month == 10 for entry in entries)
    assert (
        len([entry for entry in entries if entry.expected_date == date(2026, 10, 15)])
        == 0
    )


def test_monthly_reference_day_survives_february_and_year_shift(db, data, monkeypatch):
    plan(db, data, "2024-02-29", "monthly", reference="2024-01-31")
    result = read_calendar(db, data["ledger"], data["user"], date(2024, 3, 1))
    assert any(
        entry.expected_date == date(2024, 3, 31)
        for day in result.days
        for entry in day.income
    )
    monkeypatch.setattr(
        service,
        "fetch_bank_holidays",
        lambda year: {date(2027, 1, 1)} if year == 2027 else set(),
    )
    plan(db, data, "2027-01-01")
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 12, 1))
    assert any(
        entry.expected_date == date(2027, 1, 1) for entry in result.days[-1].income
    )


def test_api_uses_real_authorization_and_raw_sql_response(db, data):
    # 서비스가 커밋해도 테스트 종료 시 외부 트랜잭션에서 모두 롤백한다.
    with Session(bind=db, join_transaction_mode="create_savepoint") as session:
        app.dependency_overrides[get_db] = lambda: session
        app.dependency_overrides[get_current_user_id] = lambda: data["user"]
        try:
            with TestClient(app) as client:
                path = f"/ledgers/{data['ledger']}/calendar"
                response = client.get(path, params={"anchor_date": "2026-11-06"})
                assert response.status_code == 200
                assert len(response.json()["days"]) == 30
                cash_response = client.get(
                    path,
                    params={
                        "anchor_date": "2026-11-06",
                        "payment_method_id": str(data["cash"]),
                    },
                )
                assert cash_response.status_code == 200
                assert cash_response.json()["mode"] == "cash"
                assert cash_response.json()["payment_method_id"] == str(data["cash"])
                assert client.get(path).status_code == 422
                assert (
                    client.get(path, params={"anchor_date": "bad"}).status_code == 422
                )
                assert (
                    client.get(
                        f"/ledgers/{data['other_ledger']}/calendar",
                        params={"anchor_date": "2026-11-06"},
                    ).status_code
                    == 404
                )
        finally:
            app.dependency_overrides.clear()


@pytest.fixture
def wallet_client(db, data, monkeypatch):
    """순차 HTTP 요청마다 별도 세션을 열고 테스트의 외부 트랜잭션은 유지한다."""

    def request_db():
        """서비스가 커밋한 변경을 다음 요청에서 다시 읽을 수 있게 한다."""
        with Session(bind=db, join_transaction_mode="create_savepoint") as session:
            yield session

    monkeypatch.setitem(app.dependency_overrides, get_db, request_db)
    monkeypatch.setitem(
        app.dependency_overrides, get_current_user_id, lambda: data["user"]
    )
    with TestClient(app) as client:
        yield client


def test_updated_card_color_in_wallet_and_calendar(db, data, wallet_client):
    """카드 색상 변경 후 지갑과 달력의 거래 도트·마감 카드가 같은 색상을 반환한다."""
    transaction(db, data, "2026-11-12", method=data["card"])
    card_id = str(data["card"])
    color = "#ab12CD"
    wallet_path = "/users/me/payment-methods"
    response = wallet_client.patch(
        f"{wallet_path}/{card_id}/color", json={"color": color}
    )
    assert response.status_code == 200
    assert response.json() == {
        "id": card_id,
        "name": "Chase",
        "type": "credit",
        "closing_day": 12,
        "color": color,
    }

    wallet = wallet_client.get(wallet_path)
    assert wallet.status_code == 200
    assert (
        next(method for method in wallet.json() if method["id"] == card_id)
        == response.json()
    )
    calendar = wallet_client.get(
        f"/ledgers/{data['ledger']}/calendar", params={"anchor_date": "2026-11-12"}
    )
    assert calendar.status_code == 200
    closing_day = next(
        day for day in calendar.json()["days"] if day["date"] == "2026-11-12"
    )
    assert (
        next(
            dot["color"]
            for dot in closing_day["dots"]
            if dot["payment_method_id"] == card_id
        )
        == color
    )
    assert (
        next(
            card["color"]
            for card in closing_day["closing_cards"]
            if card["id"] == card_id
        )
        == color
    )


def test_patch_color_hides_foreign_and_missing_methods(db, data, wallet_client):
    """타인의 카드와 없는 카드는 같은 404를 반환하고 타인의 저장값을 보존한다."""
    for method_id in (data["foreign"], uuid4()):
        response = wallet_client.patch(
            f"/users/me/payment-methods/{method_id}/color", json={"color": "#FF55CC"}
        )
        assert response.status_code == 404
        assert response.json()["detail"] == "Payment method not found"
    assert (
        db.scalar(
            text("SELECT color FROM payment_methods WHERE id = :id"),
            {"id": data["foreign"]},
        )
        == "#000000"
    )


def test_calendar_requires_authentication():
    with TestClient(app) as client:
        assert (
            client.get(
                f"/ledgers/{uuid4()}/calendar?anchor_date=2026-11-06"
            ).status_code
            == 401
        )


def test_weekend_after_friday_month_end_moves_into_window(db, data):
    plan(db, data, "2026-08-01")
    plan(db, data, "2026-08-02")
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 7, 1))
    assert {entry.expected_date for entry in result.days[-1].income} == {
        date(2026, 8, 1),
        date(2026, 8, 2),
    }


def test_holiday_provider_failure_uses_original_date_or_stale_cache(
    db, data, monkeypatch
):
    from app.integrations.bankday import BankdayUnavailable

    def unavailable(year):
        raise BankdayUnavailable("offline")

    monkeypatch.setattr(service, "fetch_bank_holidays", unavailable)
    plan(db, data, "2026-11-08")  # Sunday, unadjusted if no calendar is known.
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 11, 1))
    assert len(result.days[7].income) == 1
    db.execute(
        insert(BankCalendarYear.__table__),
        {
            "year": 2026,
            "holidays": ["2026-11-06"],
            "fetched_at": datetime(2026, 1, 1, tzinfo=UTC),
        },
    )
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 11, 1))
    assert result.days[4].income[0].expected_date == date(2026, 11, 8)


def test_confirmed_occurrence_is_received_without_duplicate_plan(db, data):
    source = plan(db, data, "2026-11-30", "monthly", reference="2026-10-31")
    seed_insert(
        db,
        IncomeRecord.__table__,
        {
            "ledger_id": data["ledger"],
            "income_source_id": source,
            "income_type": "paycheck",
            "amount_cents": 1200,
            "expected_date": date(2026, 10, 31),
            "received_at": date(2026, 10, 30),
        },
    )
    result = read_calendar(db, data["ledger"], data["user"], date(2026, 10, 1))
    entries = [entry for day in result.days for entry in day.income]
    assert len(entries) == 1
    assert entries[0].status == "received"
    assert result.days[29].received_income_cents == 1200


def test_constant_query_count_and_explain(db, data):
    from sqlalchemy import event

    for _ in range(30):
        transaction(db, data, "2026-11-06", item_count=2)
    queries = []

    def record_query(connection, cursor, statement, parameters, context, executemany):
        queries.append(statement)

    event.listen(db, "before_cursor_execute", record_query)
    try:
        result = read_calendar(db, data["ledger"], data["user"], date(2026, 11, 1))
    finally:
        event.remove(db, "before_cursor_execute", record_query)
    assert len(queries) == 3  # Bounds, paycheck existence, one full aggregate.
    assert result.days[5].spending_cents == 3000
    statement = repository.calendar_statement(
        data["ledger"], data["user"], result.start_date, result.end_date, None
    )
    explanation = db.execute(
        text("EXPLAIN (ANALYZE, FORMAT JSON) " + repository.CALENDAR_SQL),
        statement.compile().params,
    ).scalar_one()[0]
    assert explanation["Plan"]["Actual Rows"] == 1
    print(
        f"Calendar SQL execution: {explanation['Execution Time']} ms; planning: {explanation['Planning Time']} ms"
    )


def test_dart_adapter_over_http_to_postgres(db, data):
    """Optional real transport test without requiring a Supabase Auth session."""
    import socket
    import subprocess
    import threading
    import time
    from pathlib import Path

    import uvicorn

    dart = os.environ.get("CALENDAR_TEST_DART")
    if not dart:
        pytest.skip(
            "Set CALENDAR_TEST_DART to a Dart executable for the cross-stack smoke test"
        )
    transaction(db, data, "2026-11-06", amount=130, item_count=1)
    with Session(bind=db, join_transaction_mode="create_savepoint") as session:
        app.dependency_overrides[get_db] = lambda: session
        app.dependency_overrides[get_current_user_id] = lambda: data["user"]
        server = uvicorn.Server(
            uvicorn.Config(app, log_level="error", access_log=False)
        )
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
            thread = threading.Thread(
                target=server.run, kwargs={"sockets": [listener]}, daemon=True
            )
            thread.start()
            try:
                for _ in range(500):
                    if server.started or not thread.is_alive():
                        break
                    time.sleep(0.01)
                assert server.started
                result = subprocess.run(
                    [dart, "run", "test/support/calendar_http_smoke.dart"],
                    cwd=Path(__file__).resolve().parents[2] / "frontend",
                    env={
                        **os.environ,
                        "CALENDAR_SMOKE_URL": f"http://127.0.0.1:{port}",
                        "CALENDAR_SMOKE_LEDGER": str(data["ledger"]),
                        "CALENDAR_SMOKE_CARD": str(data["card"]),
                    },
                    check=False,
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                assert result.returncode == 0, result.stdout + result.stderr
                print(result.stdout.strip())
            finally:
                server.should_exit = True
                thread.join(timeout=10)
                app.dependency_overrides.clear()
