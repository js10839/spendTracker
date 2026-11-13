from datetime import date
from unittest.mock import Mock
from uuid import uuid4

import pytest

from app.calendar import service


def test_calendar_read_commits_after_success(monkeypatch):
    """달력 조회가 성공하면 휴일 캐시 변경을 확정한다."""
    db = Mock()
    result = object()
    read = Mock(return_value=result)
    monkeypatch.setattr(service, "_read_calendar", read)
    ledger_id, user_id = uuid4(), uuid4()
    anchor_date = date(2026, 11, 11)

    assert service.read_calendar(db, ledger_id, user_id, anchor_date) is result
    read.assert_called_once_with(db.connection.return_value, ledger_id=ledger_id, user_id=user_id, anchor_date=anchor_date, payment_method_id=None)
    db.commit.assert_called_once_with()
    db.rollback.assert_not_called()


def test_calendar_read_rolls_back_on_failure(monkeypatch):
    """달력 조회가 실패하면 변경을 취소하고 오류를 전달한다."""
    db = Mock()
    monkeypatch.setattr(service, "_read_calendar", Mock(side_effect=RuntimeError("조회 실패")))

    with pytest.raises(RuntimeError, match="조회 실패"):
        service.read_calendar(db, uuid4(), uuid4(), date(2026, 11, 11))

    db.rollback.assert_called_once_with()
    db.commit.assert_not_called()
