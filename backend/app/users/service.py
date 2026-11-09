from uuid import UUID

from fastapi import HTTPException, status
from fastapi.concurrency import run_in_threadpool
from sqlalchemy.orm import Session

from app.auth.admin import (
    AuthAdminUnavailable,
    auth_user_exists,
    delete_auth_user,
    ensure_auth_admin_configured,
)
from app.db.models.user import User
from app.db.session import SessionLocal
from app.ledgers import repository as ledger_repo
from app.payment_methods import repository as payment_method_repo
from app.users import repository as user_repo


def bootstrap_user(db: Session, user_id: UUID, ledger_name: str) -> User:
    """프로필·가계부·멤버십과 기본 Cash를 한 트랜잭션으로 초기화한다."""
    try:
        # 같은 사용자의 다른 bootstrap이 끝난 뒤 현재 DB 상태를 확인한다.
        user_repo.lock_bootstrap(db=db, user_id=user_id)

        # 잠금을 획득한 뒤 삭제 진행 상태를 확인한다.
        ensure_user_not_deleting(db=db, user_id=user_id, for_write=True)

        exit_user = user_repo.find_user_by_id(db=db, user_id=user_id)
        if exit_user is not None and exit_user.deletion_requested_at is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Account deletion is in progress")
        if exit_user is not None and payment_method_repo.find_cash_payment_method(db=db, user_id=user_id) is not None:
            return exit_user

        user = exit_user
        if user is None:
            user = user_repo.add_user(db=db, user_id=user_id)
            # 공유 가계부 도입 시 개인 기본 가계부의 식별·선택 정책을 별도로 정한다.
            ledger = ledger_repo.add_ledger(db=db, owner_user_id=user_id, name=ledger_name)
            ledger_repo.add_ledger_member(db=db, ledger_id=ledger.id, user_id=user_id, role="owner")

        # Cash는 카드·은행 이체와 구분되는 기본 현금 결제수단이다.
        payment_method_repo.add_payment_method(db=db, user_id=user_id, name="Cash", method_type="cash-like", closing_day=None, color="#FCA05A")
        db.commit()
        return user
    except Exception:
        db.rollback()
        raise

def get_user_profile(db: Session, user_id: UUID) -> User:
    """인증된 사용자의 앱 프로필을 조회한다."""
    user = user_repo.find_user_by_id(db, user_id=user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User profile not found")
    return user

def update_user_profile(db: Session, user_id: UUID, nickname: str) -> User:
    """인증된 사용자의 표시 이름을 수정하고 저장한다."""
    try:
        user = get_user_profile(db, user_id=user_id)
        user_repo.update_user_nickname(db, user=user, nickname=nickname)
        db.commit()
        return user
    except Exception:
        db.rollback()
        raise

def delete_user_app_data(db: Session, user_id: UUID) -> None:
    """사용자가 소유한 앱 데이터를 한 트랜잭션에서 삭제한다."""
    try:
        # Bootstrap과 계정 삭제가 같은 사용자 데이터를 동시에 초기화·삭제하지 않게 한다.
        user_repo.lock_bootstrap(db=db, user_id=user_id)
        # Bootstrap 전 사용자도 삭제 진행 상태를 기록할 프로필이 필요하다.
        if user_repo.lock_user_by_id(db, user_id=user_id) is None:
            user_repo.add_user(db, user_id=user_id)
        # 삭제 상태를 먼저 기록해 이후 쓰기 요청이 완료까지 기다리게 한다.
        user_repo.mark_user_deletion_requested(db, user_id=user_id)
        ledger_ids = user_repo.list_owned_ledger_ids(db, user_id=user_id)
        user_repo.delete_ledger_transactions(db, ledger_ids=ledger_ids)
        user_repo.delete_ledger_income_and_notes(db, ledger_ids=ledger_ids)
        user_repo.delete_user_data(db, user_id=user_id, ledger_ids=ledger_ids)
        db.commit()
    except Exception:
        db.rollback()
        raise

def delete_user_app_data_in_session(user_id: UUID) -> None:
    """별도 Session에서 사용자의 앱 데이터 삭제를 실행한다."""
    with SessionLocal() as db:
        delete_user_app_data(db, user_id=user_id)

async def delete_account(user_id: UUID) -> None:
    """앱 데이터와 Supabase Auth 계정을 삭제한다."""
    try:
        ensure_auth_admin_configured()

        # 이전 요청에서 Auth 삭제가 완료됐다면 다시 앱 데이터를 만들지 않는다.
        if not await auth_user_exists(user_id):
            return
        await run_in_threadpool(delete_user_app_data_in_session, user_id)
        await delete_auth_user(user_id)
    except AuthAdminUnavailable as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Account deletion could not be completed; retry later") from exc

def ensure_user_not_deleting(db: Session, user_id: UUID, for_write: bool = False) -> None:
    """계정 삭제가 진행 중이면 일반 API 사용을 막는다."""
    user = user_repo.lock_user_by_id(db, user_id=user_id, shared=True) if for_write else user_repo.find_user_by_id(db, user_id=user_id)

    if user is not None and user.deletion_requested_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Account deletion is in progress")
