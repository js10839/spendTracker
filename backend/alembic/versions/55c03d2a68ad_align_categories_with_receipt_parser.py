"""align categories with receipt parser

Revision ID: 55c03d2a68ad
Revises: db6d9bf52a06
Create Date: 2026-11-06 12:11:34.615024

"""
from collections.abc import Sequence
from uuid import uuid4

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = '55c03d2a68ad'
down_revision: str | Sequence[str] | None = 'db6d9bf52a06'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """공통 카테고리 이름과 설명을 영수증 파서에 맞춘다."""
    op.execute(
        sa.text(
            "UPDATE categories SET name = :new_name "
            "WHERE name = :old_name"
        ).bindparams(
            new_name="Utilities & Bills",
            old_name="Utilities·Bills",
        )
    )

    op.execute(
        sa.text(
            "UPDATE categories SET description = :description "
            "WHERE name = :name"
        ).bindparams(
            name="Dining",
            description="레스토랑, 배달, 술집 등에서 구매한 음식과 음료. 커피 전문점의 커피는 Coffee.",
        )
    )

    op.execute(
        sa.text(
            "INSERT INTO categories (id, name, description, is_default) "
            "VALUES (:id, :name, :description, true)"
        ).bindparams(
            sa.bindparam("id", uuid4(), type_=sa.Uuid()),
            sa.bindparam("name", "Coffee", type_=sa.Text()),
            sa.bindparam("description", "커피 전문점 등에서 구매한 커피.", type_=sa.Text()),
        )
    )


def downgrade() -> None:
    """Coffee가 연결된 거래의 이전 정책을 정하기 전까지 되돌리기를 막는다."""
    raise NotImplementedError(
        "Cannot downgrade without deciding how to migrate Coffee transactions"
    )
