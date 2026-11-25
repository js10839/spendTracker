"""Remove calendar day notes.

Revision ID: e60dcaf31b72
Revises: bddcfc4a0a05
"""

import sqlalchemy as sa

from alembic import op

revision = "e60dcaf31b72"
down_revision = "bddcfc4a0a05"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """날짜 메모 기능을 폐기하므로 테이블과 저장된 메모를 함께 삭제한다."""
    op.drop_table("day_notes", schema="public")


def downgrade() -> None:
    """이전 앱이 사용하는 빈 테이블을 복원한다. 삭제된 메모 내용은 복원할 수 없다."""
    op.create_table(
        "day_notes",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "ledger_id", sa.Uuid(), sa.ForeignKey("public.ledgers.id"), nullable=False
        ),
        sa.Column("note_date", sa.Date(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint("ledger_id", "note_date", name="uq_day_notes_ledger_date"),
        schema="public",
    )
