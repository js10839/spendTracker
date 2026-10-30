from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models.user import User


def find_user_by_id(db: Session, user_id: UUID) -> User | None:
    """Supabase Auth UUID와 같은 ID의 앱 프로필을 조회한다."""
    return db.get(User, user_id)


def add_user(db: Session, user_id: UUID) -> User:
    """앱 프로필을 추가하고 commit 없이 INSERT를 실행한다."""
    user = User(id=user_id)
    db.add(user)
    db.flush()
    return user

def update_user_nickname(db: Session, user: User, nickname: str) -> User:
    """사용자 프로필의 표시 이름을 변경한다."""
    user.nickname = nickname
    db.flush()
    return user
