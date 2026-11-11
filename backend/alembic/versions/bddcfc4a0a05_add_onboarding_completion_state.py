"""add onboarding completion state

Revision ID: bddcfc4a0a05
Revises: 55c03d2a68ad
Create Date: 2026-11-09 23:05:21.913387

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'bddcfc4a0a05'
down_revision: str | Sequence[str] | None = '55c03d2a68ad'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """사용자의 가입 정보 입력 완료 상태를 추가한다."""
    op.add_column(
        "users",
        sa.Column(
            "onboarding_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    """가입 정보 완료 상태 컬럼을 제거한다."""
    op.drop_column("users", "onboarding_completed")
