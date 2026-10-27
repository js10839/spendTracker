from datetime import UTC, date, datetime, timedelta
from unittest.mock import Mock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.base import Base
from app.db.models.bank_calendar_year import BankCalendarYear
from app.db.models.income_source import IncomeSource
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.income import router as income_router
from app.income import service
from app.income.payday_calendar import adjust_paycheck_date
from app.integrations import bankday
from app.ledgers.dependencies import get_user_ledger
from app.main import app


def test_bankday_fetches_yearly_us_fed_holidays(monkeypatch: pytest.MonkeyPatch) -> None:
    """Bankday 연간 목록 요청에 은행 달력과 연도를 전달한다."""
    response = Mock()
    response.json.return_value = {"holidays": [{"date": "2026-01-01"}, {"date": "2026-07-04"}]}
    get = Mock(return_value=response)
    monkeypatch.setattr(bankday.settings, "bankday_key", "test-key")
    monkeypatch.setattr(bankday.httpx, "get", get)

    assert bankday.fetch_bank_holidays(2026) == {date(2026, 1, 1), date(2026, 7, 4)}
    get.assert_called_once_with("https://bankday.dev/v1/holidays", params={"calendar": "us-fed", "year": 2026}, headers={"Authorization": "Bearer test-key"}, timeout=5.0)
    response.raise_for_status.assert_called_once_with()


def test_paycheck_adjustment_uses_preceding_business_day() -> None:
    """주말과 은행 휴일이 연속되면 직전 영업일까지 이동한다."""
    assert adjust_paycheck_date(date(2026, 1, 19), {date(2026, 1, 19)}) == date(2026, 1, 16)
    assert adjust_paycheck_date(date(2026, 7, 4), set()) == date(2026, 7, 3)


def test_calendar_cache_reuses_year_and_refreshes_after_30_days(monkeypatch: pytest.MonkeyPatch) -> None:
    """같은 연도는 DB 캐시를 공유하고 30일 후 새 목록을 저장한다."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, tables=[BankCalendarYear.__table__])
    fetch = Mock(side_effect=[{date(2026, 1, 1)}, {date(2026, 1, 1), date(2026, 7, 3)}])
    monkeypatch.setattr(service, "fetch_bank_holidays", fetch)

    with Session(engine) as db:
        assert service.get_bank_holidays(db, 2026) == {date(2026, 1, 1)}
        assert service.get_bank_holidays(db, 2026) == {date(2026, 1, 1)}
        assert fetch.call_count == 1
        row = db.get(BankCalendarYear, 2026)
        row.fetched_at = datetime.now(UTC) - timedelta(days=31)
        db.commit()
        assert service.get_bank_holidays(db, 2026) == {date(2026, 1, 1), date(2026, 7, 3)}
        assert fetch.call_count == 2
        assert db.get(BankCalendarYear, 2026).holidays == ["2026-01-01", "2026-07-03"]
    engine.dispose()


def test_calendar_cache_uses_saved_holidays_when_bankday_fails(monkeypatch: pytest.MonkeyPatch) -> None:
    """외부 API 오류 때는 마지막 목록을 사용하고 캐시가 없으면 조정일을 비운다."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, tables=[BankCalendarYear.__table__])
    monkeypatch.setattr(service, "fetch_bank_holidays", Mock(side_effect=bankday.BankdayUnavailable("Bankday unavailable")))

    with Session(engine) as db:
        assert service.get_bank_holidays(db, 2026) is None
        db.add(BankCalendarYear(year=2026, holidays=["2026-07-03"], fetched_at=datetime.now(UTC) - timedelta(days=31)))
        db.commit()
        assert service.get_bank_holidays(db, 2026) == {date(2026, 7, 3)}
    engine.dispose()


def test_paycheck_adjustment_checks_previous_year_at_boundary(monkeypatch: pytest.MonkeyPatch) -> None:
    """1월 초 휴일이 전년도 12월로 넘어가면 이전 연도 달력도 확인한다."""
    source = IncomeSource(id=uuid4(), ledger_id=uuid4(), income_type="paycheck", from_name="Company", payment_method_id=None, expected_amount_cents=1000, memo=None, frequency="once", reference_date=date(2027, 1, 1), next_expected_date=date(2027, 1, 1), is_active=True)
    holidays = Mock(side_effect=lambda db, year: {date(2027, 1, 1)} if year == 2027 else {date(2026, 12, 31)})
    monkeypatch.setattr(service, "get_bank_holidays", holidays)

    result = service.build_income_plan_read(Mock(), source)

    assert result.adjusted_expected_date == date(2026, 12, 30)
    assert [call.args[1] for call in holidays.call_args_list] == [2027, 2026]


@pytest.mark.parametrize("income_type", ["paycheck", "other"])
def test_income_plan_read_keeps_base_date_and_only_adjusts_paycheck(monkeypatch: pytest.MonkeyPatch, income_type: str) -> None:
    """반복 기준일은 유지하고 급여에만 은행 영업일 조정을 적용한다."""
    source = IncomeSource(id=uuid4(), ledger_id=uuid4(), income_type=income_type, from_name="Company" if income_type == "paycheck" else None, payment_method_id=None, expected_amount_cents=1000, memo=None, frequency="once", reference_date=date(2026, 7, 4), next_expected_date=date(2026, 7, 4), is_active=True)
    holidays = Mock(return_value={date(2026, 7, 3)})
    monkeypatch.setattr(service, "get_bank_holidays", holidays)

    result = service.build_income_plan_read(Mock(), source)

    assert result.next_expected_date == date(2026, 7, 4)
    assert result.adjusted_expected_date == (date(2026, 7, 2) if income_type == "paycheck" else date(2026, 7, 4))
    assert source.next_expected_date == date(2026, 7, 4)
    assert holidays.call_count == (1 if income_type == "paycheck" else 0)


def test_income_plan_list_returns_adjusted_date_in_api(monkeypatch: pytest.MonkeyPatch) -> None:
    """예정 수입 조회 응답에 기준일과 조정된 표시일을 모두 전달한다."""
    user_id, ledger_id = uuid4(), uuid4()
    source = IncomeSource(id=uuid4(), ledger_id=ledger_id, income_type="paycheck", from_name="Company", payment_method_id=None, expected_amount_cents=1000, memo=None, frequency="once", reference_date=date(2026, 7, 4), next_expected_date=date(2026, 7, 4), is_active=True)
    monkeypatch.setattr(income_router, "list_ledger_income_sources", Mock(return_value=[source]))
    monkeypatch.setattr(service, "get_bank_holidays", Mock(return_value=set()))
    app.dependency_overrides[get_current_user_id] = lambda: user_id
    app.dependency_overrides[get_user_ledger] = lambda: Ledger(id=ledger_id, name="Personal", owner_user_id=user_id)
    app.dependency_overrides[get_db] = lambda: Mock()

    try:
        with TestClient(app) as client:
            response = client.get(f"/ledgers/{ledger_id}/income-plans")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()[0]["next_expected_date"] == "2026-07-04"
    assert response.json()[0]["adjusted_expected_date"] == "2026-07-03"
