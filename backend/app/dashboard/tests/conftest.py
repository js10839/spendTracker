"""Opt-in PostgreSQL fixtures, retained in test2/test2_auth.

DASHBOARD_TEST_DB_URL or DASHBOARD_TEST_USE_CONFIGURED_DB=1 enables DB tests.
Per-test ledger IDs and seed IDs are stable. An indexed registry lookup skips
base creation on repeat runs; row inserts use ON CONFLICT DO NOTHING.
No financial samples or schemas are deleted after tests.
"""

import os
from datetime import UTC, date, datetime
from uuid import NAMESPACE_URL, uuid5

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.schema import CreateSchema

import app.db.models  # noqa: F401 -- register model metadata
from app.core.config import settings
from app.dashboard import service
from app.db.base import Base


@pytest.fixture(scope="module")
def dashboard_engine():
    # CI already supplies its disposable PostgreSQL URL for calendar tests.
    url = os.environ.get("DASHBOARD_TEST_DB_URL") or os.environ.get(
        "CALENDAR_TEST_DB_URL"
    )
    if not url and os.environ.get("DASHBOARD_TEST_USE_CONFIGURED_DB") == "1":
        url = settings.db_url
    if not url:
        pytest.skip("Opt into PostgreSQL with DASHBOARD_TEST_USE_CONFIGURED_DB=1")
    engine = create_engine(url, connect_args={"connect_timeout": 10})
    try:
        with engine.begin() as conn:
            conn.execute(CreateSchema("test2", if_not_exists=True))
            conn.execute(CreateSchema("test2_auth", if_not_exists=True))
        isolated = engine.execution_options(
            schema_translate_map={None: "test2", "auth": "test2_auth"}
        )
        Base.metadata.create_all(isolated)
        with isolated.begin() as conn:
            conn.execute(text("SET LOCAL search_path TO test2"))
            conn.execute(
                text("""
                CREATE TABLE IF NOT EXISTS dashboard_test_cases (
                    name text PRIMARY KEY, version integer NOT NULL
                )
            """)
            )
            for year in range(2023, 2029):
                holidays = '["2027-01-01"]' if year == 2027 else "[]"
                conn.execute(
                    text("""
                    INSERT INTO bank_calendar_years (year, holidays, fetched_at)
                    VALUES (:year, CAST(:holidays AS json), :now)
                    ON CONFLICT (year) DO UPDATE
                    SET holidays = EXCLUDED.holidays, fetched_at = EXCLUDED.fetched_at
                """),
                    {"year": year, "holidays": holidays, "now": datetime.now(UTC)},
                )
        yield isolated
    finally:
        engine.dispose()


class Samples:
    def __init__(self, connection, name):
        self.db, self.name = connection, name

    def id(self, key):
        return uuid5(NAMESPACE_URL, f"spendTracker/dashboard/v1/{self.name}/{key}")

    def insert(self, table, key, **values):
        # Identifiers are internal test constants, never request input.
        columns = ["id", *values]
        self.db.execute(
            text(
                f"INSERT INTO {table} ({', '.join(columns)}) "
                f"VALUES ({', '.join(':' + c for c in columns)}) "
                "ON CONFLICT (id) DO NOTHING"
            ),
            {"id": self.id(key), **values},
        )
        return self.id(key)

    def seed_base(self):
        if self.db.scalar(
            text(
                "SELECT 1 FROM dashboard_test_cases WHERE name = :name AND version = 1"
            ),
            {"name": self.name},
        ):
            return
        for user in ("user", "other"):
            self.insert("test2_auth.users", user)
            self.insert("users", user)
        for ledger, user in (("ledger", "user"), ("other_ledger", "other")):
            self.insert("ledgers", ledger, owner_user_id=self.id(user), name=ledger)
        self.db.execute(
            text("""
                INSERT INTO ledger_members (ledger_id, user_id, role)
                VALUES (:ledger_id, :user_id, 'owner') ON CONFLICT DO NOTHING
            """),
            {"ledger_id": self.id("ledger"), "user_id": self.id("user")},
        )
        for key, user, closing in (
            ("card", "user", 12),
            ("second", "user", 31),
            ("cash", "user", None),
            ("foreign", "other", 8),
        ):
            self.insert(
                "payment_methods",
                key,
                user_id=self.id(user),
                name=key,
                type="credit" if closing else "cash-like",
                closing_day=closing,
                color="#3366FF",
            )
        for name in ("Food", "Travel", "Shopping", "Other"):
            self.insert("categories", name, name=f"{name} {self.id(name)}")
        self.db.execute(
            text("INSERT INTO dashboard_test_cases (name, version) VALUES (:name, 1)"),
            {"name": self.name},
        )

    def tx(
        self,
        key,
        day,
        amount,
        method="card",
        ledger="ledger",
        items=(),
        deleted=False,
        currency="USD",
    ):
        identifier = self.insert(
            "transactions",
            key,
            ledger_id=self.id(ledger),
            payment_method_id=self.id(method),
            transacted_at=date.fromisoformat(day),
            total_cents=amount,
            currency=currency,
            deleted_at=datetime.now(UTC) if deleted else None,
        )
        for index, (category, cents) in enumerate(items):
            self.insert(
                "transaction_items",
                f"{key}/item/{index}",
                transaction_id=identifier,
                category_id=self.id(category),
                name=f"Item {index}",
                amount_cents=cents,
            )
        return identifier

    def plan(self, key, expected, frequency="once", amount=1000, **extras):
        values = {
            "ledger_id": self.id("ledger"),
            "income_type": "paycheck",
            "from_name": key,
            "expected_amount_cents": amount,
            "reference_date": date.fromisoformat(expected),
            "next_expected_date": date.fromisoformat(expected),
            "frequency": frequency,
        }
        return self.insert("income_sources", key, **{**values, **extras})

    def read(self, as_of="2026-11-13", **params):
        return service._read_dashboard(
            self.db,
            ledger_id=self.id("ledger"),
            user_id=self.id("user"),
            as_of=date.fromisoformat(as_of),
            **params,
        )


@pytest.fixture
def samples(dashboard_engine, monkeypatch, request):
    # The shared bank cache is preseeded with deterministic holidays. No Bankday
    # HTTP requests or writes to the public cache during SQL tests.
    monkeypatch.setattr(service, "ensure_bank_year", lambda conn, year: None)
    with dashboard_engine.connect() as conn:
        transaction = conn.begin()
        conn.execute(text("SET LOCAL search_path TO test2"))
        assert conn.scalar(text("SELECT current_schema()")) == "test2"
        data = Samples(conn, request.node.nodeid)
        data.seed_base()
        try:
            yield data
        finally:
            transaction.commit()
