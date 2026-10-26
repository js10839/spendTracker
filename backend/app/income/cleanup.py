"""배포 환경의 일일 스케줄러가 호출할 수입 정리 명령이다."""

from app.db.session import SessionLocal
from app.income.service import purge_expired_income


def main() -> None:
    """30일이 지난 실제 수입과 예정 규칙을 정리하고 건수를 출력한다."""
    with SessionLocal() as db:
        records_deleted, sources_deleted = purge_expired_income(db)
    print(f"Purged {records_deleted} income records and {sources_deleted} income plans")


if __name__ == "__main__":
    main()