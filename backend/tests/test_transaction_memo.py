from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.pool import StaticPool

from app.auth.dependencies import get_active_user_id, get_current_user_id
from app.db.session import get_db
from app.db.tables import metadata, transaction_items, transactions
from app.ledgers import repository as ledgers_repository
from app.ledgers.dependencies import get_user_ledger
from app.main import app
from app.transactions import router as transactions_router


def test_memo_patch_changes_only_memo_and_respects_ledger():
    """메모 변경·삭제가 다른 거래 필드와 품목을 바꾸지 않는지 확인한다."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    metadata.create_all(engine, tables=[transactions, transaction_items])
    ledger_id, other_ledger_id, card_id, category_id = (uuid4() for _ in range(4))
    with engine.connect() as db:
        transaction = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=card_id, merchant='Cafe', transacted_at=date(2026, 11, 13), memo='old', source='receipt_parse', total_cents=1200, tax_cents=100, tip_cents=100).returning(transactions)).one()
        other = db.execute(transactions.insert().values(id=uuid4(), ledger_id=other_ledger_id, payment_method_id=card_id, transacted_at=date(2026, 11, 13), total_cents=100).returning(transactions)).one()
        deleted = db.execute(transactions.insert().values(id=uuid4(), ledger_id=ledger_id, payment_method_id=card_id, transacted_at=date(2026, 11, 13), total_cents=100, deleted_at=datetime.now(UTC)).returning(transactions)).one()
        item = db.execute(transaction_items.insert().values(transaction_id=transaction.id, category_id=category_id, name='Coffee', amount_cents=1000).returning(transaction_items)).one()
        db.commit()
        item_id = item.id
        app.dependency_overrides[get_user_ledger] = lambda: SimpleNamespace(id=ledger_id, name="Personal", owner_user_id=uuid4())
        app.dependency_overrides[get_db] = lambda: db
        try:
            with TestClient(app) as client:
                path = f"/ledgers/{ledger_id}/transactions/{transaction.id}/memo"
                response = client.patch(path, json={"memo": "  lunch  "})
                assert response.status_code == 200
                assert response.json() == {"id": str(transaction.id), "memo": "  lunch  "}
                for blank in ["", "  ", None]:
                    response = client.patch(path, json={"memo": blank})
                    assert response.status_code == 200
                    assert response.json()["memo"] is None
                assert client.patch(path, json={}).status_code == 422
                assert client.patch(path, json={"memo": "test", "total_cents": 1}).status_code == 422
                for transaction_id in [other.id, deleted.id, uuid4()]:
                    assert client.patch(f"/ledgers/{ledger_id}/transactions/{transaction_id}/memo", json={"memo": "x"}).status_code == 404
        finally:
            app.dependency_overrides.clear()
        saved = db.execute(select(transactions).where(transactions.c.id == transaction.id)).one_or_none()
        saved_item = db.execute(select(transaction_items).where(transaction_items.c.id == item_id)).one_or_none()
        assert (saved.payment_method_id, saved.merchant, saved.transacted_at, saved.source, saved.total_cents, saved.tax_cents, saved.tip_cents) == (card_id, "Cafe", date(2026, 11, 13), "receipt_parse", 1200, 100, 100)
        assert (saved_item.transaction_id, saved_item.name, saved_item.category_id, saved_item.amount_cents) == (transaction.id, "Coffee", category_id, 1000)
    engine.dispose()


@pytest.mark.parametrize("payload", [{"memo": "hello"}, {"memo": None}])
def test_memo_patch_requires_authentication(payload):
    """인증되지 않은 요청은 가계부 접근 전에 거부한다."""
    with TestClient(app) as client:
        assert client.patch(f"/ledgers/{uuid4()}/transactions/{uuid4()}/memo", json=payload).status_code == 401


def test_memo_patch_rejects_nonmember(monkeypatch):
    """가계부 멤버가 아니면 메모 수정 서비스가 호출되지 않는다."""
    user_id = uuid4()
    update_memo = Mock()
    monkeypatch.setattr(transactions_router, "update_ledger_transaction_memo", update_memo)
    monkeypatch.setattr(ledgers_repository, "find_member_ledger", Mock(return_value=None))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_active_user_id] = lambda: user_id
    app.dependency_overrides[get_db] = lambda: Mock()
    try:
        with TestClient(app) as client:
            response = client.patch(f"/ledgers/{uuid4()}/transactions/{uuid4()}/memo", json={"memo": "test"})
        assert response.status_code == 404
        update_memo.assert_not_called()
    finally:
        app.dependency_overrides.clear()
