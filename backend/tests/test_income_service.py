from datetime import date
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.db.models.payment_method import PaymentMethod
from app.income import repository, service
from app.income.schema import IncomePlanConfirm, IncomeRecordCreate


@pytest.mark.parametrize(("reference_date", "frequency", "expected"), [(date(2026, 10, 23), "biweekly", date(2026, 11, 6)), (date(2026, 1, 31), "monthly", date(2026, 2, 28)), (date(2026, 12, 31), "monthly", date(2027, 1, 31))])
def test_calculate_next_expected_date(reference_date, frequency, expected) -> None:
    """격주 및 월말·연말 경계에서 다음 Paycheck 예상일을 계산한다."""
    assert service.calculate_next_expected_date(reference_date, frequency) == expected


def test_create_recurring_paycheck_saves_source_and_record(monkeypatch) -> None:
    """반복 Paycheck는 규칙과 실제 수입을 같은 트랜잭션에 저장한다."""
    db = Mock()
    ledger_id, user_id, source_id = uuid4(), uuid4(), uuid4()
    data = IncomeRecordCreate(income_type="paycheck", amount_cents=250000, received_at=date(2026, 1, 31), from_name="Company", frequency="monthly")
    source = IncomeSource(id=source_id)
    record = IncomeRecord(id=uuid4(), ledger_id=ledger_id, income_source_id=source_id)
    add_source = Mock(return_value=source)
    add_record = Mock(return_value=record)
    monkeypatch.setattr(repository, "add_income_source", add_source)
    monkeypatch.setattr(repository, "add_income_record", add_record)

    assert service.create_income_record(db, ledger_id, user_id, data) is record

    add_source.assert_called_once_with(db, ledger_id=ledger_id, from_name="Company", expected_amount_cents=250000, frequency="monthly", reference_date=date(2026, 1, 31), next_expected_date=date(2026, 2, 28))
    add_record.assert_called_once_with(db, ledger_id=ledger_id, income_source_id=source_id, payment_method_id=None, income_type="paycheck", from_name="Company", amount_cents=250000, received_at=date(2026, 1, 31), memo=None)
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_create_cashback_uses_owned_payment_method(monkeypatch) -> None:
    """Cashback은 현재 사용자 소유 결제수단에만 연결한다."""
    db = Mock()
    ledger_id, user_id, payment_method_id = uuid4(), uuid4(), uuid4()
    data = IncomeRecordCreate(income_type="cashback", amount_cents=500, received_at=date(2026, 10, 23), applied_to=payment_method_id)
    method = PaymentMethod(id=payment_method_id, user_id=user_id)
    record = IncomeRecord(id=uuid4(), ledger_id=ledger_id, payment_method_id=payment_method_id)
    find_method = Mock(return_value=method)
    add_source = Mock()
    add_record = Mock(return_value=record)
    monkeypatch.setattr(repository, "find_user_payment_method", find_method)
    monkeypatch.setattr(repository, "add_income_source", add_source)
    monkeypatch.setattr(repository, "add_income_record", add_record)

    assert service.create_income_record(db, ledger_id, user_id, data) is record

    find_method.assert_called_once_with(db, payment_method_id=payment_method_id, user_id=user_id)
    add_source.assert_not_called()
    assert add_record.call_args.kwargs["payment_method_id"] == payment_method_id
    db.commit.assert_called_once_with()


def test_create_other_income_does_not_link_payment_method(monkeypatch) -> None:
    """Other 수입은 결제수단 ID 없이 저장한다."""
    db = Mock()
    ledger_id, user_id = uuid4(), uuid4()
    data = IncomeRecordCreate(income_type="other", amount_cents=1000, received_at=date(2026, 10, 23))
    find_method = Mock()
    add_record = Mock(return_value=IncomeRecord(id=uuid4(), ledger_id=ledger_id))
    monkeypatch.setattr(repository, "find_user_payment_method", find_method)
    monkeypatch.setattr(repository, "add_income_record", add_record)

    service.create_income_record(db, ledger_id, user_id, data)

    find_method.assert_not_called()
    assert add_record.call_args.kwargs["payment_method_id"] is None
    assert add_record.call_args.kwargs["income_type"] == "other"
    db.commit.assert_called_once_with()


def test_create_income_record_rejects_unowned_payment_method(monkeypatch) -> None:
    """다른 사용자 결제수단을 선택하면 수입을 저장하지 않는다."""
    db = Mock()
    data = IncomeRecordCreate(income_type="cashback", amount_cents=500, received_at=date(2026, 10, 23), applied_to=uuid4())
    add_record = Mock()
    monkeypatch.setattr(repository, "find_user_payment_method", Mock(return_value=None))
    monkeypatch.setattr(repository, "add_income_record", add_record)

    with pytest.raises(HTTPException) as raised:
        service.create_income_record(db, uuid4(), uuid4(), data)

    assert raised.value.status_code == 404
    add_record.assert_not_called()
    db.commit.assert_not_called()


def test_create_income_record_rolls_back_when_record_insert_fails(monkeypatch) -> None:
    """규칙 저장 후 기록 저장이 실패하면 Service가 전체 작업을 되돌린다."""
    db = Mock()
    data = IncomeRecordCreate(income_type="paycheck", amount_cents=250000, received_at=date(2026, 10, 23), from_name="Company", frequency="biweekly")
    monkeypatch.setattr(repository, "add_income_source", Mock(return_value=IncomeSource(id=uuid4())))
    monkeypatch.setattr(repository, "add_income_record", Mock(side_effect=RuntimeError("DB error")))

    with pytest.raises(RuntimeError, match="DB error"):
        service.create_income_record(db, uuid4(), uuid4(), data)

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()


def test_confirm_monthly_income_keeps_original_day_and_actual_amount(monkeypatch) -> None:
    """월말 반복 일정은 원래 일자를 유지하고 변경 금액은 이번 기록에만 쓴다."""
    db = Mock()
    ledger_id, source_id = uuid4(), uuid4()
    source = IncomeSource(id=source_id, ledger_id=ledger_id, income_type="paycheck", from_name="Company", expected_amount_cents=20000, frequency="monthly", reference_date=date(2026, 1, 31), next_expected_date=date(2026, 2, 28), is_active=True)
    record = IncomeRecord(id=uuid4(), ledger_id=ledger_id, income_source_id=source_id)

    monkeypatch.setattr(repository, "find_active_income_source", Mock(return_value=source))
    add_record = Mock(return_value=record)
    update_source = Mock()
    monkeypatch.setattr(repository, "add_income_record", add_record)
    monkeypatch.setattr(repository, "update_income_source_state", update_source)

    result = service.confirm_income_plan(db, ledger_id, source_id, IncomePlanConfirm(expected_date=date(2026, 2, 28), received_at=date(2026, 3, 1), amount_cents=19500))

    assert result is record
    assert add_record.call_args.kwargs["amount_cents"] == 19500
    assert source.expected_amount_cents == 20000
    assert update_source.call_args.kwargs["next_expected_date"] == date(2026, 3, 31)
    assert update_source.call_args.kwargs["is_active"] is True
    db.commit.assert_called_once()
