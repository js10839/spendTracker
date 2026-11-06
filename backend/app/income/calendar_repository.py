from datetime import datetime

from sqlalchemy.orm import Session

from app.db.models.bank_calendar_year import BankCalendarYear


def find_calendar_year(db: Session, year: int) -> BankCalendarYear | None:
    """DB에 저장된 연간 은행 휴일을 조회한다."""
    return db.get(BankCalendarYear, year)


def save_calendar_year(db: Session, year: int, holidays: list[str], fetched_at: datetime) -> BankCalendarYear:
    """연간 은행 휴일을 저장하거나 기존 목록을 갱신한다."""
    calendar = find_calendar_year(db, year)
    if calendar is None:
        calendar = BankCalendarYear(year=year, holidays=holidays, fetched_at=fetched_at)
        db.add(calendar)
    else:
        calendar.holidays = holidays
        calendar.fetched_at = fetched_at
    db.flush()
    return calendar
