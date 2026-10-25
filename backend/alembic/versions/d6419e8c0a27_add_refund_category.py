"""add shared Refund spending category

Revision ID: d6419e8c0a27
Revises: e8a91f4c2d73

"""

from collections.abc import Sequence
from uuid import UUID

import sqlalchemy as sa

from alembic import op

revision: str = "d6419e8c0a27"
down_revision: str | Sequence[str] | None = "e8a91f4c2d73"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None
REFUND_CATEGORY_ID = UUID("3e7c0c8e-8d52-4f8e-a8c3-2eb0b73789e4")


def upgrade() -> None:
    """모든 가계부가 사용하는 Refund 지출 카테고리를 추가한다."""
    op.execute(
        sa.text("INSERT INTO categories (id, name, description, is_default) VALUES (:id, 'Refund', '구매 금액을 돌려받아 지출에서 차감한 품목.', true) ON CONFLICT (name) DO NOTHING")
        .bindparams(sa.bindparam("id", REFUND_CATEGORY_ID, type_=sa.Uuid()))
    )


def downgrade() -> None:
    """Refund 품목이 참조 중이면 FK가 카테고리 제거를 막는다."""
    op.execute(sa.text("DELETE FROM categories WHERE id = :id").bindparams(sa.bindparam("id", REFUND_CATEGORY_ID, type_=sa.Uuid())))
