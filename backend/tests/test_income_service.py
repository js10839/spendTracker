from datetime import UTC, date, datetime, timedelta
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.db.models.payment_method import PaymentMethod
from app.income import repository, service
from app.income.schema import (
    IncomePlanConfirm,
    IncomePlanUpdate,
    IncomeRecordCreate,
    IncomeRecordUpdate,
)


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


@pytest.mark.parametrize(("expected_date", "frequency", "reference_date"), [(date(2026, 2, 28), "monthly", date(2026, 1, 31)), (date(2026, 3, 5), "monthly", date(2026, 3, 5)), (date(2026, 2, 28), "biweekly", date(2026, 2, 28))])
def test_update_income_plan_preserves_or_resets_schedule_anchor(monkeypatch, expected_date, frequency, reference_date) -> None:
    """금액만 바꾸면 월말 기준일을 유지하고 날짜·주기를 바꾸면 새 기준일을 쓴다."""
    db = Mock()
    ledger_id, user_id, source_id = uuid4(), uuid4(), uuid4()
    source = IncomeSource(id=source_id, ledger_id=ledger_id, income_type="paycheck", from_name="Company", expected_amount_cents=20000, frequency="monthly", reference_date=date(2026, 1, 31), next_expected_date=date(2026, 2, 28), is_active=True)
    monkeypatch.setattr(repository, "find_active_income_source", Mock(return_value=source))
    update_source = Mock(return_value=source)
    monkeypatch.setattr(repository, "update_income_source_details", update_source)
    data = IncomePlanUpdate(expected_amount_cents=22000, expected_date=expected_date, frequency=frequency, from_name="Company")

    assert service.update_ledger_income_plan(db, ledger_id, user_id, source_id, data) is source

    assert update_source.call_args.kwargs["reference_date"] == reference_date
    assert update_source.call_args.kwargs["next_expected_date"] == expected_date
    db.commit.assert_called_once()


def test_update_cashback_record_rejects_unowned_payment_method(monkeypatch) -> None:
    """Cashback 기록 수정으로 다른 사용자의 결제수단을 연결하지 못한다."""
    db = Mock()
    ledger_id, user_id, record_id, payment_method_id = uuid4(), uuid4(), uuid4(), uuid4()
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_type="cashback", amount_cents=500, received_at=date(2026, 10, 23))
    monkeypatch.setattr(repository, "find_income_record", Mock(return_value=record))
    find_method = Mock(return_value=None)
    update_record = Mock()
    monkeypatch.setattr(repository, "find_user_payment_method", find_method)
    monkeypatch.setattr(repository, "update_income_record", update_record)
    data = IncomeRecordUpdate(amount_cents=600, received_at=date(2026, 10, 24), applied_to=payment_method_id)

    with pytest.raises(HTTPException) as raised:
        service.update_ledger_income_record(db, ledger_id, user_id, record_id, data)

    assert raised.value.status_code == 404
    find_method.assert_called_once_with(db, payment_method_id=payment_method_id, user_id=user_id)
    update_record.assert_not_called()
    db.rollback.assert_called_once()
    db.commit.assert_not_called()


@pytest.mark.parametrize(("frequency", "is_active", "next_expected_date"), [("once", False, date(2026, 10, 25)), ("monthly", True, date(2026, 11, 25))])
def test_undo_income_confirmation_reopens_original_occurrence(monkeypatch, frequency, is_active, next_expected_date) -> None:
    """일회성·반복 입금 확정 취소는 실제 기록을 숨기고 원래 예정일을 복원한다."""
    db = Mock()
    ledger_id, source_id, record_id = uuid4(), uuid4(), uuid4()
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_source_id=source_id, expected_date=date(2026, 10, 25))
    source = IncomeSource(id=source_id, ledger_id=ledger_id, frequency=frequency, reference_date=date(2026, 10, 25), next_expected_date=next_expected_date, is_active=is_active)
    monkeypatch.setattr(repository, "find_income_record", Mock(return_value=record))
    monkeypatch.setattr(repository, "find_income_source_for_undo", Mock(return_value=source))
    mark_deleted = Mock()
    update_source = Mock()
    monkeypatch.setattr(repository, "mark_income_record_deleted", mark_deleted)
    monkeypatch.setattr(repository, "update_income_source_state", update_source)

    assert service.undo_income_confirmation(db, ledger_id, record_id) is source

    assert mark_deleted.call_args.kwargs["record"] is record
    assert mark_deleted.call_args.kwargs["deleted_at"].tzinfo is not None
    update_source.assert_called_once_with(db, source=source, next_expected_date=date(2026, 10, 25), is_active=True)
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_undo_income_confirmation_rejects_changed_plan(monkeypatch) -> None:
    """다음 회차가 이미 진행된 경우 이전 확정의 Undo가 예정 상태를 되감지 않는다."""
    db = Mock()
    ledger_id, source_id, record_id = uuid4(), uuid4(), uuid4()
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_source_id=source_id, expected_date=date(2026, 10, 25))
    source = IncomeSource(id=source_id, ledger_id=ledger_id, frequency="monthly", reference_date=date(2026, 10, 25), next_expected_date=date(2026, 12, 25), is_active=True)
    monkeypatch.setattr(repository, "find_income_record", Mock(return_value=record))
    monkeypatch.setattr(repository, "find_income_source_for_undo", Mock(return_value=source))
    mark_deleted = Mock()
    monkeypatch.setattr(repository, "mark_income_record_deleted", mark_deleted)

    with pytest.raises(HTTPException) as raised:
        service.undo_income_confirmation(db, ledger_id, record_id)

    assert raised.value.status_code == 409
    mark_deleted.assert_not_called()
    db.commit.assert_not_called()
    db.rollback.assert_called_once_with()


def test_soft_delete_income_record_does_not_change_plan(monkeypatch) -> None:
    """일반 기록 삭제는 계획의 예정 회차를 다시 열지 않는다."""
    db = Mock()
    ledger_id, record_id = uuid4(), uuid4()
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_source_id=uuid4())
    monkeypatch.setattr(repository, "find_income_record", Mock(return_value=record))
    mark_deleted = Mock()
    update_source = Mock()
    monkeypatch.setattr(repository, "mark_income_record_deleted", mark_deleted)
    monkeypatch.setattr(repository, "update_income_source_state", update_source)

    service.soft_delete_income_record(db, ledger_id, record_id)

    assert mark_deleted.call_args.kwargs["record"] is record
    update_source.assert_not_called()
    db.commit.assert_called_once_with()


def test_restore_deleted_income_plan_commits_within_retention(monkeypatch) -> None:
    """보관 기간이 남은 예정 수입만 관리자 복구를 통해 다시 표시한다."""
    db = Mock()
    ledger_id, source_id = uuid4(), uuid4()
    source = IncomeSource(id=source_id, ledger_id=ledger_id, deleted_at=datetime.now(UTC) - timedelta(days=1))
    find_source = Mock(return_value=source)
    restore_source = Mock()
    monkeypatch.setattr(repository, "find_restorable_income_source", find_source)
    monkeypatch.setattr(repository, "restore_income_source", restore_source)

    service.restore_deleted_income_plan_for_admin(db, ledger_id, source_id)

    assert find_source.call_args.kwargs["cutoff"] < source.deleted_at
    restore_source.assert_called_once_with(db, source=source)
    db.commit.assert_called_once_with()


@pytest.mark.parametrize(("next_expected_date", "has_active_record"), [(date(2026, 10, 25), False), (date(2026, 11, 25), True)])
def test_restore_deleted_income_record_rejects_duplicate_occurrence(monkeypatch, next_expected_date, has_active_record) -> None:
    """Undo로 열린 회차나 재확정된 회차에 과거 기록을 중복 복구하지 않는다."""
    db = Mock()
    ledger_id, source_id, record_id = uuid4(), uuid4(), uuid4()
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_source_id=source_id, expected_date=date(2026, 10, 25), deleted_at=datetime.now(UTC) - timedelta(days=1))
    source = IncomeSource(id=source_id, ledger_id=ledger_id, next_expected_date=next_expected_date, is_active=True)
    monkeypatch.setattr(repository, "find_restorable_income_record", Mock(return_value=record))
    monkeypatch.setattr(repository, "find_income_source_for_undo", Mock(return_value=source))
    monkeypatch.setattr(repository, "has_active_income_record_for_occurrence", Mock(return_value=has_active_record))
    restore_record = Mock()
    monkeypatch.setattr(repository, "restore_income_record", restore_record)

    with pytest.raises(HTTPException) as raised:
        service.restore_deleted_income_record_for_admin(db, ledger_id, record_id)

    assert raised.value.status_code == 409
    restore_record.assert_not_called()
    db.commit.assert_not_called()
    db.rollback.assert_called_once_with()


def test_restore_deleted_income_record_allows_general_delete(monkeypatch) -> None:
    """예정 회차가 이미 넘어간 일반 삭제 기록은 보관 기간 내에 복구한다."""
    db = Mock()
    ledger_id, source_id, record_id = uuid4(), uuid4(), uuid4()
    record = IncomeRecord(id=record_id, ledger_id=ledger_id, income_source_id=source_id, expected_date=date(2026, 10, 25), deleted_at=datetime.now(UTC) - timedelta(days=1))
    source = IncomeSource(id=source_id, ledger_id=ledger_id, next_expected_date=date(2026, 11, 25), is_active=True)
    monkeypatch.setattr(repository, "find_restorable_income_record", Mock(return_value=record))
    monkeypatch.setattr(repository, "find_income_source_for_undo", Mock(return_value=source))
    monkeypatch.setattr(repository, "has_active_income_record_for_occurrence", Mock(return_value=False))
    restore_record = Mock()
    monkeypatch.setattr(repository, "restore_income_record", restore_record)

    service.restore_deleted_income_record_for_admin(db, ledger_id, record_id)

    restore_record.assert_called_once_with(db, record=record)
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_purge_expired_income_commits_records_before_sources(monkeypatch) -> None:
    """만료 기록을 모두 정리한 다음 예정 규칙을 정리하고 배치마다 commit한다."""
    events = []
    db = Mock()
    db.commit.side_effect = lambda: events.append("commit")
    record_counts = iter((2, 1))
    source_counts = iter((1,))
    monkeypatch.setattr(repository, "delete_expired_income_record_batch", lambda *args, **kwargs: events.append("records") or next(record_counts))
    monkeypatch.setattr(repository, "delete_expired_income_source_batch", lambda *args, **kwargs: events.append("sources") or next(source_counts))
    monkeypatch.setattr(service, "sleep", lambda seconds: None)

    assert service.purge_expired_income(db, batch_size=2) == (3, 1)

    assert events == ["records", "commit", "records", "commit", "sources", "commit"]
    db.rollback.assert_not_called()


def test_income_calendar_combines_received_and_planned_dates(monkeypatch) -> None:
    """실제 입금일과 반복 예정일을 각각 달력 표시 날짜로 반환한다."""
    db = Mock()
    ledger_id, source_id = uuid4(), uuid4()
    record = IncomeRecord(id=uuid4(), ledger_id=ledger_id, income_source_id=None, income_type="other", from_name=None, payment_method_id=None, amount_cents=1000, received_at=date(2026, 10, 15), memo=None, expected_date=None)
    source = IncomeSource(id=source_id, ledger_id=ledger_id, income_type="paycheck", from_name="Company", payment_method_id=None, expected_amount_cents=200000, memo=None, frequency="monthly", reference_date=date(2026, 10, 31), next_expected_date=date(2026, 10, 31), is_active=True)
    monkeypatch.setattr(repository, "list_income_records_in_range", Mock(return_value=[record]))
    monkeypatch.setattr(repository, "list_active_income_sources", Mock(return_value=[source]))
    monkeypatch.setattr(service, "get_adjusted_paycheck_date", lambda db, day: date(2026, 10, 30) if day == date(2026, 10, 31) else day)

    entries = service.list_income_calendar(db, ledger_id, date(2026, 10, 1), date(2026, 11, 30))

    assert [(entry.status, entry.display_date) for entry in entries] == [
        ("received", date(2026, 10, 15)),
        ("planned", date(2026, 10, 30)),
        ("planned", date(2026, 11, 30)),
    ]
