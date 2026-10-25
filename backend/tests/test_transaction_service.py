from datetime import date
from unittest.mock import Mock
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException

from app.db.models.category import Category
from app.db.models.payment_method import PaymentMethod
from app.db.models.transaction import Transaction
from app.db.models.transaction_item import TransactionItem
from app.transactions import repository, service
from app.transactions.schema import ManualTransactionGroupCreate, TransactionGroupUpdate


def _create_data(payment_method_id: UUID, category_id: UUID) -> ManualTransactionGroupCreate:
    """품목 한 개와 결제 전체 Tax·Tip이 있는 요청을 만든다."""
    return ManualTransactionGroupCreate(payment_method_id=payment_method_id, merchant="Cafe", transacted_at=date(2026, 10, 18), tax_cents=100, tip_cents=200, items=[{"name": "Sandwich", "category_id": category_id, "amount_cents": 1299}])


def _update_data(payment_method_id: UUID, item_id: UUID, category_id: UUID) -> TransactionGroupUpdate:
    """기존 품목 ID를 포함한 전체 수정 요청을 만든다."""
    return TransactionGroupUpdate(payment_method_id=payment_method_id, merchant="New Cafe", transacted_at=date(2026, 10, 20), tax_cents=200, tip_cents=300, items=[{"id": item_id, "name": "New Sandwich", "category_id": category_id, "amount_cents": 2500}])


def _saved_group(ledger_id: UUID, payment_method_id: UUID, category_id: UUID, source: str = "manual") -> tuple[Transaction, TransactionItem]:
    """저장된 결제와 기존 품목을 같은 ID 관계로 만든다."""
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id, payment_method_id=payment_method_id, merchant="Cafe", transacted_at=date(2026, 10, 18), source=source, total_cents=1599, tax_cents=100, tip_cents=200)
    item = TransactionItem(id=uuid4(), transaction_id=transaction.id, category_id=category_id, name="Sandwich", amount_cents=1299)
    return transaction, item


def test_create_grouped_transaction_commits_stored_total(monkeypatch) -> None:
    """Service는 소유권과 카테고리를 확인하고 저장된 총액을 반환한다."""
    user_id, ledger_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    data = _create_data(payment_method_id, category_id)
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    db = Mock()
    find_payment = Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id))
    find_category = Mock(return_value=Category(id=category_id, name="Food"))
    add_group = Mock(return_value=(transaction, [item]))
    monkeypatch.setattr(repository, "find_user_payment_method", find_payment)
    monkeypatch.setattr(repository, "find_global_category", find_category)
    monkeypatch.setattr(repository, "add_grouped_manual_transaction", add_group)

    result = service.create_grouped_manual_transaction(db, ledger_id, user_id, data)

    assert result.total_cents == 1599
    assert result.items[0].id == item.id
    find_payment.assert_called_once_with(db, payment_method_id=payment_method_id, user_id=user_id)
    find_category.assert_called_once_with(db, category_id=category_id)
    assert add_group.call_args.kwargs["items"] == [("Sandwich", category_id, 1299)]
    assert add_group.call_args.kwargs["total_cents"] == 1599
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_create_refund_item_normalizes_amount_and_total(monkeypatch) -> None:
    """Refund 품목은 양수로 입력해도 음수로 저장하고 총액에서 차감한다."""
    ledger_id, user_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    data = ManualTransactionGroupCreate(payment_method_id=payment_method_id, transacted_at=date(2026, 10, 25), items=[{"name": "Returned shirt", "category_id": category_id, "amount_cents": 1000}])
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id, payment_method_id=payment_method_id, transacted_at=data.transacted_at, source="manual", total_cents=-1000, tax_cents=0, tip_cents=0)
    item = TransactionItem(id=uuid4(), transaction_id=transaction.id, name="Returned shirt", category_id=category_id, amount_cents=-1000)
    db = Mock()
    add_group = Mock(return_value=(transaction, [item]))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=category_id, name="Refund")))
    monkeypatch.setattr(repository, "add_grouped_manual_transaction", add_group)

    result = service.create_grouped_manual_transaction(db, ledger_id, user_id, data)

    assert add_group.call_args.kwargs["items"] == [("Returned shirt", category_id, -1000)]
    assert add_group.call_args.kwargs["total_cents"] == -1000
    assert result.total_cents == -1000


def test_create_transaction_keeps_zero_and_negative_non_refund_items(monkeypatch) -> None:
    """일반 카테고리의 0원·음수 품목을 유지해 총액에 반영한다."""
    ledger_id, user_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    data = ManualTransactionGroupCreate(payment_method_id=payment_method_id, transacted_at=date(2026, 10, 25), items=[{"name": "Free item", "category_id": category_id, "amount_cents": 0}, {"name": "Discount", "category_id": category_id, "amount_cents": -250}])
    transaction = Transaction(id=uuid4(), ledger_id=ledger_id, payment_method_id=payment_method_id, transacted_at=data.transacted_at, source="manual", total_cents=-250, tax_cents=0, tip_cents=0)
    items = [TransactionItem(id=uuid4(), transaction_id=transaction.id, name=item.name, category_id=category_id, amount_cents=item.amount_cents) for item in data.items]
    db = Mock()
    add_group = Mock(return_value=(transaction, items))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=category_id, name="Food")))
    monkeypatch.setattr(repository, "add_grouped_manual_transaction", add_group)

    result = service.create_grouped_manual_transaction(db, ledger_id, user_id, data)

    assert add_group.call_args.kwargs["items"] == [("Free item", category_id, 0), ("Discount", category_id, -250)]
    assert add_group.call_args.kwargs["total_cents"] == -250
    assert result.total_cents == -250


def test_create_grouped_transaction_rejects_other_users_payment_method(monkeypatch) -> None:
    """다른 사용자 결제수단이면 품목을 저장하지 않는다."""
    db = Mock()
    data = _create_data(uuid4(), uuid4())
    add_group = Mock()
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=None))
    monkeypatch.setattr(repository, "add_grouped_manual_transaction", add_group)

    with pytest.raises(HTTPException) as raised:
        service.create_grouped_manual_transaction(db, uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    add_group.assert_not_called()
    db.commit.assert_not_called()


def test_create_grouped_transaction_rejects_unknown_category(monkeypatch) -> None:
    """공통 카테고리에 없는 품목은 저장하지 않는다."""
    db = Mock()
    data = _create_data(uuid4(), uuid4())
    add_group = Mock()
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=data.payment_method_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=None))
    monkeypatch.setattr(repository, "add_grouped_manual_transaction", add_group)

    with pytest.raises(HTTPException) as raised:
        service.create_grouped_manual_transaction(db, uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    add_group.assert_not_called()
    db.commit.assert_not_called()


def test_create_grouped_transaction_rolls_back_on_write_failure(monkeypatch) -> None:
    """결제·품목 저장에 실패하면 Service가 rollback한다."""
    db = Mock()
    data = _create_data(uuid4(), uuid4())
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=data.payment_method_id)))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=data.items[0].category_id)))
    monkeypatch.setattr(repository, "add_grouped_manual_transaction", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        service.create_grouped_manual_transaction(db, uuid4(), uuid4(), data)

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_list_transactions_groups_items_without_committing(monkeypatch) -> None:
    """기간 조회는 품목과 독립적으로 저장된 총액을 반환한다."""
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    transaction.total_cents = 1700
    db = Mock()
    find_transactions = Mock(return_value=[transaction])
    find_items = Mock(return_value=[item])
    monkeypatch.setattr(repository, "list_ledger_transactions", find_transactions)
    monkeypatch.setattr(repository, "list_transaction_items", find_items)

    result = service.list_ledger_transactions(db, ledger_id, date(2026, 10, 1), date(2026, 10, 31))

    assert len(result) == 1
    assert result[0].total_cents == 1700
    assert result[0].items[0].id == item.id
    find_items.assert_called_once_with(db, [transaction.id])
    db.commit.assert_not_called()


def test_list_transactions_rejects_reversed_dates(monkeypatch) -> None:
    """조회 시작일이 종료일보다 늦으면 DB를 조회하지 않는다."""
    find_transactions = Mock()
    monkeypatch.setattr(repository, "list_ledger_transactions", find_transactions)

    with pytest.raises(HTTPException) as raised:
        service.list_ledger_transactions(Mock(), uuid4(), date(2026, 11, 1), date(2026, 10, 31))

    assert raised.value.status_code == 422
    find_transactions.assert_not_called()


def test_update_transaction_keeps_existing_item_id_for_receipt_source(monkeypatch) -> None:
    """영수증 입력 거래도 기존 품목 ID를 유지하며 수정한다."""
    user_id, ledger_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id, source="receipt_parse")
    data = _update_data(payment_method_id, item.id, category_id)
    db = Mock()
    apply_update = Mock(return_value=[])
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=category_id)))
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    result = service.update_transaction_group(db, ledger_id, transaction.id, user_id, data)

    assert result.items[0].id == item.id
    assert result.source == "receipt_parse"
    assert apply_update.call_args.kwargs["item_updates"] == [(item, "New Sandwich", category_id, 2500)]
    assert apply_update.call_args.kwargs["total_cents"] == 3000
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_update_refund_item_recalculates_negative_total(monkeypatch) -> None:
    """기존 품목을 Refund로 바꾸면 같은 ID에 음수 금액을 저장한다."""
    ledger_id, user_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    data = _update_data(payment_method_id, item.id, category_id)
    data.items[0].amount_cents = 1000
    db = Mock()
    apply_update = Mock(return_value=[])
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=category_id, name="Refund")))
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    service.update_transaction_group(db, ledger_id, transaction.id, user_id, data)

    assert apply_update.call_args.kwargs["item_updates"] == [(item, "New Sandwich", category_id, -1000)]
    assert apply_update.call_args.kwargs["total_cents"] == -500


@pytest.mark.parametrize("requested_ids", ["unknown", "duplicate"])
def test_update_transaction_rejects_invalid_item_set(monkeypatch, requested_ids: str) -> None:
    """모르는 품목과 중복 품목은 수정하지 않는다."""
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    data = _update_data(payment_method_id, item.id, category_id)
    if requested_ids == "unknown":
        data.items[0].id = uuid4()
    elif requested_ids == "duplicate":
        data.items.append(data.items[0].model_copy())
    db = Mock()
    apply_update = Mock()
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    with pytest.raises(HTTPException) as raised:
        service.update_transaction_group(db, ledger_id, transaction.id, uuid4(), data)

    assert raised.value.status_code == 422
    apply_update.assert_not_called()
    db.commit.assert_not_called()


def test_update_transaction_rejects_missing_transaction(monkeypatch) -> None:
    """현재 가계부에 없는 거래는 수정하지 않는다."""
    data = _update_data(uuid4(), uuid4(), uuid4())
    find_payment = Mock()
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=None))
    monkeypatch.setattr(repository, "find_user_payment_method", find_payment)

    with pytest.raises(HTTPException) as raised:
        service.update_transaction_group(Mock(), uuid4(), uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    find_payment.assert_not_called()


def test_update_transaction_rejects_other_users_payment_method(monkeypatch) -> None:
    """다른 사용자 결제수단이면 품목 조회나 수정에 들어가지 않는다."""
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    data = _update_data(payment_method_id, item.id, category_id)
    list_items = Mock()
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=None))
    monkeypatch.setattr(repository, "list_transaction_items", list_items)

    with pytest.raises(HTTPException) as raised:
        service.update_transaction_group(Mock(), ledger_id, transaction.id, uuid4(), data)

    assert raised.value.status_code == 404
    list_items.assert_not_called()


def test_update_transaction_rejects_unknown_category(monkeypatch) -> None:
    """품목 카테고리가 공통 목록에 없으면 변경하지 않는다."""
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    data = _update_data(payment_method_id, item.id, uuid4())
    db = Mock()
    apply_update = Mock()
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=None))
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    with pytest.raises(HTTPException) as raised:
        service.update_transaction_group(db, ledger_id, transaction.id, uuid4(), data)

    assert raised.value.status_code == 404
    apply_update.assert_not_called()
    db.commit.assert_not_called()


def test_update_transaction_rolls_back_on_write_failure(monkeypatch) -> None:
    """결제와 품목의 변경에 실패하면 Service가 rollback한다."""
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    data = _update_data(payment_method_id, item.id, category_id)
    db = Mock()
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=category_id)))
    monkeypatch.setattr(repository, "apply_transaction_update", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        service.update_transaction_group(db, ledger_id, transaction.id, uuid4(), data)

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_update_transaction_rejects_removing_all_items(monkeypatch) -> None:
    """수동 거래도 마지막 품목을 지운 상태로 저장할 수 없다."""
    user_id, ledger_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    data = _update_data(payment_method_id, item.id, category_id)
    data.items = []
    db = Mock()
    apply_update = Mock(return_value=[])
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    with pytest.raises(HTTPException) as raised:
        service.update_transaction_group(db, ledger_id, transaction.id, user_id, data)

    assert raised.value.status_code == 422
    assert raised.value.detail == "Transactions require at least one item"
    apply_update.assert_not_called()
    db.commit.assert_not_called()


def test_update_receipt_transaction_rejects_empty_items(monkeypatch) -> None:
    """영수증 거래는 품목을 모두 지운 상태로 저장하지 못한다."""
    ledger_id, payment_method_id, category_id = uuid4(), uuid4(), uuid4()
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id, source="receipt_parse")
    data = _update_data(payment_method_id, item.id, category_id)
    data.items = []
    find_payment = Mock()
    apply_update = Mock()
    db = Mock()
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", find_payment)
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    with pytest.raises(HTTPException) as raised:
        service.update_transaction_group(db, ledger_id, transaction.id, uuid4(), data)

    assert raised.value.status_code == 422
    assert raised.value.detail == "Transactions require at least one item"
    find_payment.assert_not_called()
    apply_update.assert_not_called()
    db.commit.assert_not_called()


def test_update_transaction_adds_item_without_replacing_existing_id(monkeypatch) -> None:
    """새 품목만 새 ID를 받고 기존 품목 ID는 유지한다."""
    user_id, ledger_id, payment_method_id, category_id = (uuid4() for _ in range(4))
    transaction, item = _saved_group(ledger_id, payment_method_id, category_id)
    created = TransactionItem(id=uuid4(), transaction_id=transaction.id, category_id=category_id, name="Apples", amount_cents=500)
    data = _update_data(payment_method_id, item.id, category_id)
    data.items.append(type(data.items[0]).model_validate({"name": "Apples", "category_id": category_id, "amount_cents": 500}))
    db = Mock()
    apply_update = Mock(return_value=[created])
    monkeypatch.setattr(repository, "find_ledger_transaction", Mock(return_value=transaction))
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=PaymentMethod(id=payment_method_id, user_id=user_id)))
    monkeypatch.setattr(repository, "list_transaction_items", Mock(return_value=[item]))
    monkeypatch.setattr(repository, "find_global_category", Mock(return_value=Category(id=category_id)))
    monkeypatch.setattr(repository, "apply_transaction_update", apply_update)

    result = service.update_transaction_group(db, ledger_id, transaction.id, user_id, data)

    assert [saved.id for saved in result.items] == [item.id, created.id]
    assert apply_update.call_args.kwargs["item_creations"] == [("Apples", category_id, 500)]
    assert apply_update.call_args.kwargs["total_cents"] == 3500
    db.commit.assert_called_once_with()
