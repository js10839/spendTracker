from datetime import UTC, date, datetime
from types import SimpleNamespace
from uuid import uuid4

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool

from app.db.session import get_db
from app.db.tables import categories, metadata, transaction_items, transactions
from app.ledgers.dependencies import get_user_ledger
from app.main import app


def test_transaction_search_matches_three_fields_and_card_filter() -> None:
    """실제 검색 API가 세 필드를 합쳐 집계하고 날짜·카드·삭제 조건을 지킨다."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    metadata.create_all(engine, tables=[categories, transactions, transaction_items])
    ledger_id, other_ledger_id, card_id, other_card_id = (uuid4() for _ in range(4))
    with engine.connect() as db:
        food = db.execute(categories.insert().values(id=uuid4(), name='Food').returning(categories)).one()
        coffee_category = db.execute(categories.insert().values(id=uuid4(), name='Coffee').returning(categories)).one()
        cafe = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=card_id, merchant='Joe Coffee', transacted_at=date(2026, 8, 12), total_cents=1200).returning(transactions)).one()
        market = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=other_card_id, merchant='Market', transacted_at=date(2026, 8, 15), total_cents=800).returning(transactions)).one()
        category_match = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=card_id, merchant='Other', transacted_at=date(2026, 8, 18), total_cents=200).returning(transactions)).one()
        outside = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=card_id, merchant='Coffee', transacted_at=date(2026, 9, 1), total_cents=300).returning(transactions)).one()
        deleted = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=card_id, merchant='Coffee', transacted_at=date(2026, 8, 19), total_cents=300, deleted_at=datetime.now(UTC)).returning(transactions)).one()
        another_ledger = db.execute(transactions.insert().values(id=uuid4(), ledger_id=other_ledger_id, payment_method_id=card_id, merchant='Coffee', transacted_at=date(2026, 8, 20), total_cents=300).returning(transactions)).one()
        db.execute(transaction_items.insert().values(transaction_id=cafe.id, category_id=food.id, name='Latte', amount_cents=500))
        db.execute(transaction_items.insert().values(transaction_id=cafe.id, category_id=food.id, name='Cookie', amount_cents=700))
        db.execute(transaction_items.insert().values(transaction_id=market.id, category_id=food.id, name='Coffee beans', amount_cents=800))
        db.execute(transaction_items.insert().values(transaction_id=category_match.id, category_id=coffee_category.id, name='Chips', amount_cents=200))
        db.execute(transaction_items.insert().values(transaction_id=outside.id, category_id=food.id, name='Tea', amount_cents=300))
        db.execute(transaction_items.insert().values(transaction_id=deleted.id, category_id=food.id, name='Tea', amount_cents=300))
        db.execute(transaction_items.insert().values(transaction_id=another_ledger.id, category_id=food.id, name='Tea', amount_cents=300))
        db.commit()

        app.dependency_overrides[get_user_ledger] = lambda: SimpleNamespace(id=ledger_id, name="Personal", owner_user_id=uuid4())
        app.dependency_overrides[get_db] = lambda: db
        try:
            with TestClient(app) as client:
                path = f"/ledgers/{ledger_id}/transactions/search"
                params = {"query": "COFFEE", "start_date": "2026-08-01", "end_date": "2026-08-31"}
                response = client.get(path, params=params)
                filtered = client.get(path, params={**params, "payment_method_id": str(card_id)})
                literal_wildcard = client.get(path, params={**params, "query": "%"})
                empty = client.get(path, params={**params, "query": "   "})
        finally:
            app.dependency_overrides.clear()

        assert response.status_code == 200
        result = response.json()
        assert result["matched_dates"] == ["2026-08-12", "2026-08-15", "2026-08-18"]
        assert result["item_count"] == 4
        assert result["store_count"] == 3
        assert result["matched_items_total_cents"] == 2200
        assert {item["name"]: item["matched_fields"] for item in result["items"]} == {"Latte": ["store"], "Cookie": ["store"], "Coffee beans": ["item"], "Chips": ["category"]}
        assert filtered.status_code == 200
        assert filtered.json()["item_count"] == 3
        assert filtered.json()["matched_items_total_cents"] == 1400
        assert literal_wildcard.status_code == 200
        assert literal_wildcard.json()["item_count"] == 0
        assert empty.status_code == 422

    engine.dispose()
