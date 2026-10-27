from datetime import date

import httpx

from app.core.config import settings


class BankdayUnavailable(Exception):
    """Bankday 연간 달력을 사용할 수 없을 때 서비스에 전달한다."""


def fetch_bank_holidays(year: int) -> set[date]:
    """Bankday의 us-fed 달력에서 지정 연도의 은행 휴일을 한 번에 가져온다."""
    if not settings.bankday_key:
        raise BankdayUnavailable("BANKDAY_KEY is not configured")

    try:
        response = httpx.get(
            f"{settings.bankday_url}/holidays",
            params={"calendar": "us-fed", "year": year},
            headers={"Authorization": f"Bearer {settings.bankday_key}"},
            timeout=5.0,
        )
        response.raise_for_status()
        return {date.fromisoformat(holiday["date"]) for holiday in response.json()["holidays"]}
    except (httpx.HTTPError, KeyError, TypeError, ValueError) as exc:
        raise BankdayUnavailable("Bankday holiday calendar is unavailable") from exc
