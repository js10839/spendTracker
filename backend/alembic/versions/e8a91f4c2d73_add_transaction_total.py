"""store transaction total

Revision ID: e8a91f4c2d73
Revises: cab1751301e3

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e8a91f4c2d73"
down_revision: str | Sequence[str] | None = "cab1751301e3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """기존 품목 금액과 Tax/Tip 합계로 거래 총액을 채운다."""
    op.add_column("transactions", sa.Column("total_cents", sa.Integer(), nullable=True))

    # 기존 거래의 총액을 채운 뒤 필수 컬럼으로 전환한다.
    op.execute(
        sa.text(
            """
            UPDATE public.transactions AS t
            SET total_cents = COALESCE(
                (SELECT SUM(i.amount_cents)
                 FROM public.transaction_items AS i
                 WHERE i.transaction_id = t.id),
                0
            ) + t.tax_cents + t.tip_cents
            """
        )
    )
    op.alter_column("transactions", "total_cents", existing_type=sa.Integer(), nullable=False)


def downgrade() -> None:
    """총액이 별도로 저장된 거래가 없을 때만 이전 스키마로 되돌린다."""
    # 품목 합계와 다른 총액이 있을 수 있으므로 거래가 남아 있으면 컬럼을 제거하지 않는다.
    if op.get_bind().scalar(sa.text("SELECT EXISTS (SELECT 1 FROM public.transactions)")):
        raise RuntimeError("Existing transactions require preserving total_cents")

    op.drop_column("transactions", "total_cents")
