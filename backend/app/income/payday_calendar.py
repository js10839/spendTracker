from datetime import date, timedelta


def adjust_paycheck_date(target_date: date, bank_holidays: set[date]) -> date:
    """급여 기준일이 주말이나 은행 휴일이면 직전 영업일을 반환한다."""
    adjusted_date = target_date
    while adjusted_date.weekday() >= 5 or adjusted_date in bank_holidays:
        adjusted_date -= timedelta(days=1)
    return adjusted_date
