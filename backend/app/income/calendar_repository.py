from datetime import datetime

from sqlalchemy import select
from sqlalchemy.engine import Connection, Row

from app.db.tables import bank_calendar_years


def find_calendar_year(db: Connection, year: int) -> Row | None:
    """DB에 저장된 연간 은행 휴일을 조회한다."""
    statement = select(bank_calendar_years).where(bank_calendar_years.c.year == year)
    return db.execute(statement).one_or_none()


def save_calendar_year(
    db: Connection, year: int, holidays: list[str], fetched_at: datetime
) -> Row:
    """연간 은행 휴일을 저장하거나 기존 목록을 갱신한다."""
    values = {"holidays": holidays, "fetched_at": fetched_at}
    if find_calendar_year(db, year) is None:
        statement = bank_calendar_years.insert().values(year=year, **values)
    else:
        statement = (
            bank_calendar_years.update()
            .where(bank_calendar_years.c.year == year)
            .values(**values)
        )
    return db.execute(statement.returning(bank_calendar_years)).one()
