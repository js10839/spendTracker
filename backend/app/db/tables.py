from uuid import uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    MetaData,
    Table,
    Text,
    UniqueConstraint,
    Uuid,
    false,
    func,
    text,
)

metadata = MetaData()

# Supabase owns this table. The app declares it for foreign key resolution.
auth_users = Table(
    "users",
    metadata,
    Column("id", Uuid, primary_key=True),
    schema="auth",
    info={"external": True},
)


bank_calendar_years = Table(
    "bank_calendar_years",
    metadata,
    Column("year", Integer, primary_key=True),
    Column("holidays", JSON, nullable=False),
    Column("fetched_at", DateTime(timezone=True), nullable=False),
)

categories = Table(
    "categories",
    metadata,
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("name", Text, nullable=False),
    Column("icon", Text, nullable=True),
    Column("is_default", Boolean, nullable=False, server_default="false"),
    Column("description", Text, nullable=True),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
    UniqueConstraint("name", name="uq_categories_name"),
)

income_records = Table(
    "income_records",
    metadata,
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("ledger_id", Uuid, ForeignKey("ledgers.id"), nullable=False),
    Column("income_source_id", Uuid, ForeignKey("income_sources.id"), nullable=True),
    Column("payment_method_id", Uuid, ForeignKey("payment_methods.id"), nullable=True),
    Column("income_type", Text, nullable=False),
    Column("from_name", Text, nullable=True),
    Column("amount_cents", Integer, nullable=False),
    Column("received_at", Date, nullable=False),
    Column("memo", Text, nullable=True),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
    # 예정 수입을 확정해 만든 기록의 원래 예정일이다. 직접 입력한 수입은 NULL이다.
    Column("expected_date", Date, nullable=True),
    Column("deleted_at", DateTime(timezone=True), nullable=True),
    CheckConstraint("amount_cents>0", name="ck_income_records_positive_amount"),
)

income_sources = Table(
    "income_sources",
    metadata,
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("ledger_id", Uuid, ForeignKey("ledgers.id"), nullable=False),
    Column("income_type", Text, nullable=False, server_default="paycheck"),
    Column("from_name", Text, nullable=True),
    Column("payment_method_id", Uuid, ForeignKey("payment_methods.id"), nullable=True),
    Column("expected_amount_cents", Integer, nullable=False),
    Column("memo", Text, nullable=True),
    Column("frequency", Text, nullable=False),
    Column("reference_date", Date, nullable=False),
    Column("next_expected_date", Date, nullable=False),
    Column("is_active", Boolean, nullable=False, server_default="true"),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
    Column("deleted_at", DateTime(timezone=True), nullable=True),
    CheckConstraint(
        "expected_amount_cents > 0", name="ck_income_sources_positive_amount"
    ),
)

ledgers = Table(
    "ledgers",
    metadata,
    # 사용자 UUID와 별개로 새 가계부를 INSERT할 때 uuid4를 생성한다.
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("name", Text, nullable=False),
    Column("owner_user_id", Uuid, ForeignKey("users.id"), nullable=False),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
)

ledger_members = Table(
    "ledger_members",
    metadata,
    # 두 UUID의 조합이 기본 키이며 별도 멤버십 UUID는 만들지 않는다.
    Column("ledger_id", Uuid, ForeignKey("ledgers.id"), primary_key=True),
    Column("user_id", Uuid, ForeignKey("users.id"), primary_key=True),
    Column("role", Text, nullable=False),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
)

payment_methods = Table(
    "payment_methods",
    metadata,
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("user_id", Uuid, ForeignKey("users.id"), nullable=False),
    Column("name", Text, nullable=False),
    Column("type", Text, nullable=False),
    Column("closing_day", Integer, nullable=True),
    Column("color", Text, nullable=False),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
    CheckConstraint(
        "(type = 'credit' AND closing_day BETWEEN 1 AND 31) OR (type = 'cash-like' AND closing_day IS NULL)",
        name="ck_payment_methods_type_closing_day",
    ),
)

transactions = Table(
    "transactions",
    metadata,
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("ledger_id", Uuid, ForeignKey("ledgers.id"), nullable=False),
    Column("payment_method_id", Uuid, ForeignKey("payment_methods.id"), nullable=False),
    Column("currency", Text, nullable=False, server_default="USD"),
    Column("merchant", Text, nullable=True),
    Column("memo", Text, nullable=True),
    Column("transacted_at", Date, nullable=False),
    Column("source", Text, nullable=False, server_default="manual"),
    Column("total_cents", Integer, nullable=False),
    Column("tax_cents", Integer, nullable=False, server_default=text("0")),
    Column("tip_cents", Integer, nullable=False, server_default=text("0")),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
    Column("deleted_at", DateTime(timezone=True), nullable=True),
    CheckConstraint(
        "source IN ('manual', 'receipt_parse')", name="ck_transactions_source"
    ),
    Index(
        "ix_transactions_active_ledger_date",
        "ledger_id",
        "transacted_at",
        postgresql_where=text("deleted_at IS NULL"),
    ),
)

transaction_items = Table(
    "transaction_items",
    metadata,
    Column("id", Uuid, primary_key=True, default=uuid4),
    Column("transaction_id", Uuid, ForeignKey("transactions.id"), nullable=False),
    Column("category_id", Uuid, ForeignKey("categories.id"), nullable=False),
    Column("name", Text, nullable=False),
    Column("amount_cents", Integer, nullable=False),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
)

users = Table(
    "users",
    metadata,
    Column(
        "id", Uuid, ForeignKey("auth.users.id", ondelete="CASCADE"), primary_key=True
    ),
    Column("nickname", Text, nullable=True),
    Column("plan", Text, nullable=False, server_default="free"),
    Column("onboarding_completed", Boolean, nullable=False, server_default=false()),
    Column(
        "created_at", DateTime(timezone=True), server_default=func.now(), nullable=False
    ),
    Column(
        "updated_at",
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
    Column("deletion_requested_at", DateTime(timezone=True), nullable=True),
)
