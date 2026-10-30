import asyncio

from fastapi import HTTPException
from sqlalchemy.exc import SQLAlchemyError

from app.db.session import SessionLocal
from app.users import repository
from app.users.service import delete_account


async def main() -> int:
    """남아 있는 계정 삭제 요청을 재시도하고 실패 건수를 반환한다."""
    with SessionLocal() as db:
        user_ids = repository.list_pending_deletion_user_ids(db)

    failed = 0
    for user_id in user_ids:
        try:
            await delete_account(user_id)
        except (HTTPException, SQLAlchemyError):
            failed += 1

    print(f"Account deletion retries: {len(user_ids) - failed} succeeded, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
