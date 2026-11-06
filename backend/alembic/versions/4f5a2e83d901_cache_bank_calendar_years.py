"""Cache Bankday bank holidays by calendar year.

Revision ID: 4f5a2e83d901
Revises: c2b9befbaace
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "4f5a2e83d901"
down_revision: str | Sequence[str] | None = "c2b9befbaace"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """연간 은행 휴일을 공유할 테이블을 생성한다."""
    op.create_table(
        "bank_calendar_years",
        sa.Column("year", sa.Integer(), primary_key=True),
        sa.Column("holidays", sa.JSON(), nullable=False),
        sa.Column("fetched_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    """연간 은행 휴일 캐시 테이블을 제거한다."""
    op.drop_table("bank_calendar_years")
