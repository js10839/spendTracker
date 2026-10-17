"""make payment methods user owned

Revision ID: 9b0e2c7a4d11
Revises: f45e611ab334
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "9b0e2c7a4d11"
down_revision: str | None = "f45e611ab334"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """기존 결제수단을 소속 가계부의 소유자에게 이전한다."""
    op.add_column("payment_methods", sa.Column("user_id", sa.Uuid(), nullable=True))
    op.execute(
        "UPDATE payment_methods AS pm "
        "SET user_id = l.owner_user_id "
        "FROM ledgers AS l WHERE pm.ledger_id = l.id"
    )
    op.alter_column("payment_methods", "user_id", nullable=False)
    op.create_foreign_key(
        "fk_payment_methods_user_id_users",
        "payment_methods",
        "users",
        ["user_id"],
        ["id"],
    )
    op.drop_constraint(
        "payment_methods_ledger_id_fkey", "payment_methods", type_="foreignkey"
    )
    op.drop_column("payment_methods", "ledger_id")


def downgrade() -> None:
    """사용자 지갑은 여러 가계부에서 쓰일 수 있어 이전 소유 가계부를 복원할 수 없다."""
    raise NotImplementedError(
        "Cannot restore the original ledger for each payment method"
    )
