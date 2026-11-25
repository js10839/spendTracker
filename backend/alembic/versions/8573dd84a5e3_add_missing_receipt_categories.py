"""add missing receipt categories

Revision ID: 8573dd84a5e3
Revises: e60dcaf31b72
Create Date: 2026-11-25 09:45:26.581472

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '8573dd84a5e3'
down_revision: str | Sequence[str] | None = 'e60dcaf31b72'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

RECEIPT_CATEGORIES = (
    ("fa6e2847-8ccd-41c0-807e-4e47913adce3", "Grocery"),
    ("bc5e86f9-cdde-4a95-9545-308a62b41b6a", "Education"),
    ("1b09fd24-500d-4fb5-b6bd-1a79d845847c", "Drinks"),
    ("26aa3856-4788-4ff7-ae71-4d7155d62521", "Smoking"),
)


def upgrade() -> None:
    """영수증 파서가 반환하는 네 분류를 공용 지출 카테고리에 추가한다."""
    statement = sa.text("""INSERT INTO categories (id, name, is_default) VALUES (CAST(:id AS uuid), :name, true) ON CONFLICT (name) DO NOTHING""")
    for category_id, name in RECEIPT_CATEGORIES:
        op.execute(statement.bindparams(id=category_id, name=name))


def downgrade() -> None:
    """이번에 추가한 카테고리를 제거한다. 거래 품목이 참조 중이면 FK가 삭제를 막는다."""
    statement = sa.text("DELETE FROM categories WHERE id = CAST(:id AS uuid)")
    for category_id, name in RECEIPT_CATEGORIES:
        op.execute(statement.bindparams(id=category_id))
