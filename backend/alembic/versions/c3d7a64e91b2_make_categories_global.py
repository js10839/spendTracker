"""make categories global

Revision ID: c3d7a64e91b2
Revises: 9b0e2c7a4d11
"""

from collections.abc import Sequence
from uuid import uuid4

import sqlalchemy as sa

from alembic import op

revision: str = "c3d7a64e91b2"
down_revision: str | None = "9b0e2c7a4d11"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """같은 이름의 카테고리를 합치고 기존 거래를 공통 ID로 옮긴다."""
    op.execute(
        "WITH canonical AS ("
        "SELECT DISTINCT ON (name) name, id FROM categories "
        "ORDER BY name, created_at, id"
        ") UPDATE transactions AS t SET category_id = canonical.id "
        "FROM categories AS old, canonical "
        "WHERE t.category_id = old.id AND old.name = canonical.name"
    )
    op.execute(
        "WITH canonical AS ("
        "SELECT DISTINCT ON (name) name, id FROM categories "
        "ORDER BY name, created_at, id"
        ") DELETE FROM categories AS duplicate USING canonical "
        "WHERE duplicate.name = canonical.name AND duplicate.id <> canonical.id"
    )
    op.drop_constraint("categories_ledger_id_fkey", "categories", type_="foreignkey")
    op.drop_column("categories", "ledger_id")
    op.create_unique_constraint("uq_categories_name", "categories", ["name"])

    # 이 revision의 기본 목록을 고정해 새 DB도 가계부 생성 없이 동일한 12개로 시작한다.
    definitions = [
        ("Food", "직접 조리하거나 섭취할 식료품. 예: 고기, 채소, 과일, 음료, 스낵. 외식·배달은 Dining, 세제·휴지는 Living."),
        ("Living", "집에서 쓰는 생활용품·소모품. 예: 세제, 휴지, 샴푸, 수건, 주방용품, 수납용품, 가구, 가전. 옷은 Fashion, 전자기기는 Electronics."),
        ("Electronics", "전자기기·주변기기 하드웨어. 예: 폰, 노트북, 모니터, 이어폰, 충전기, 게임 콘솔. 게임 콘텐츠는 Entertainment, 디지털 구독은 Subscription, 가전은 Living."),
        ("Fashion", "몸에 걸치는 물건. 예: 옷, 신발, 가방, 액세서리, 화장품. 세탁 서비스는 Etc."),
        ("Dining", "조리된 음식·음료. 예: 레스토랑, 카페, 배달, 술집. 마트에서 산 식재료는 Food."),
        ("Transport", "일상 이동 비용. 예: 개스, 대중교통, Uber/Lyft, 주차, 차량 정비. 여행지 항공·숙박은 Travel."),
        ("Subscription", "반복 결제 디지털·멤버십 서비스. 예: Netflix, Spotify, iCloud, 짐 멤버십, Amazon Prime. 일회성 구매는 해당 카테고리로 분류."),
        ("Utilities·Bills", "주거 관련 고정 요금. 예: 전기, 수도, 주거용 개스, 인터넷, 휴대폰 요금. 렌트는 MVP 범위 밖."),
        ("Health", "건강·의료 비용. 예: 병원, 약국, 보험 본인부담금, 영양제. 짐 멤버십은 Subscription."),
        ("Entertainment", "여가·취미 소비. 예: 영화, 공연, 게임, 책, 취미용품. 반복 결제형 콘텐츠는 Subscription."),
        ("Travel", "여행 관련 지출. 예: 항공권, 호텔, 여행지 액티비티. 일상 이동은 Transport."),
        ("Etc", "다른 카테고리에 속하지 않는 지출. 예: 선물, 기부, 수수료, 분류가 애매한 지출."),
    ]
    insert_category = sa.text(
        "INSERT INTO categories (id, name, description, is_default) "
        "VALUES (:id, :name, :description, true) ON CONFLICT (name) DO NOTHING"
    )
    for name, description in definitions:
        op.execute(
            insert_category.bindparams(
                sa.bindparam("id", uuid4(), type_=sa.Uuid()),
                sa.bindparam("name", name, type_=sa.Text()),
                sa.bindparam("description", description, type_=sa.Text()),
            )
        )


def downgrade() -> None:
    """공통 카테고리의 과거 가계부별 ID는 복원할 수 없다."""
    raise NotImplementedError("Cannot restore the original per-ledger category IDs")
