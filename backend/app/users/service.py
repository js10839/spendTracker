from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.db.models.user import User
from app.ledgers import repository as ledger_repo
from app.payment_methods import repository as payment_method_repo
from app.users import repository as user_repo


def bootstrap_user(db: Session, user_id: UUID, ledger_name: str) -> User:
    """프로필·가계부·멤버십과 기본 Cash를 한 트랜잭션으로 초기화한다."""
    exist_user = user_repo.find_user_by_id(db, user_id=user_id)
    if exist_user is not None and payment_method_repo.find_cash_payment_method(db, user_id=user_id) is not None:
        return exist_user

    try:
        user = exist_user
        if user is None:
            user = user_repo.add_user(db, user_id=user_id)
            ledger = ledger_repo.add_ledger(db, owner_user_id=user_id, name=ledger_name)
            ledger_repo.add_ledger_member(
                db, ledger_id=ledger.id, user_id=user_id, role="owner"
            )

        # Cash는 카드·은행 이체와 구분되는 기본 현금 결제수단이다.
        payment_method_repo.add_payment_method(db, user_id=user_id, name="Cash", method_type="cash-like", closing_day=None, color="#FCA05A")
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
