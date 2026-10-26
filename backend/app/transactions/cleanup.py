"""배포 환경의 일일 스케줄러가 호출할 거래 정리 명령이다."""

from app.db.session import SessionLocal
from app.transactions.service import purge_expired_transactions


def main() -> None:
    """30일이 지난 거래를 정리하고 삭제 건수만 출력한다."""
    with SessionLocal() as db:
        deleted_count = purge_expired_transactions(db)
    print(f"Purged {deleted_count} expired transactions")


if __name__ == "__main__":
    main()
