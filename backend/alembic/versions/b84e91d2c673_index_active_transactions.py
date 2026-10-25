"""index active transactions by ledger and date

Revision ID: b84e91d2c673
Revises: d6419e8c0a27

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "b84e91d2c673"
down_revision: str | Sequence[str] | None = "d6419e8c0a27"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """활성 거래의 가계부·날짜 조회만 인덱싱한다."""
    op.create_index("ix_transactions_active_ledger_date", "transactions", ["ledger_id", "transacted_at"], postgresql_where=sa.text("deleted_at IS NULL"))


def downgrade() -> None:
    """활성 거래 조회용 부분 인덱스를 제거한다."""
    op.drop_index("ix_transactions_active_ledger_date", table_name="transactions")
