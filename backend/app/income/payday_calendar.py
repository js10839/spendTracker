from collections.abc import Callable
from datetime import date, timedelta


def adjust_paycheck_date(target_date: date, bank_holidays: set[date]) -> date:
    """급여 기준일이 주말이나 은행 휴일이면 직전 영업일을 반환한다."""
    adjusted_date = target_date
    while adjusted_date.weekday() >= 5 or adjusted_date in bank_holidays:
        adjusted_date -= timedelta(days=1)
    return adjusted_date


def resolve_paycheck_date(expected_date: date, holidays_for_year: Callable[[int], set[date] | None]) -> date | None:
    """연초 급여가 전년으로 넘어가면 두 연도의 은행 달력을 적용한다."""
    holidays = holidays_for_year(expected_date.year)
    if holidays is None:
        return None
    adjusted = adjust_paycheck_date(expected_date, holidays)
    if adjusted.year != expected_date.year:
        previous = holidays_for_year(adjusted.year)
        if previous is None:
            return None
        adjusted = adjust_paycheck_date(adjusted, previous)
    return adjusted
