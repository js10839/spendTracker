"""PostgreSQL calendar queries. Only Core tables/columns and mapping results.

Independent collections are aggregated before joining them to the date spine:
items cannot multiply transaction totals, nor can income multiply dot counts.
"""

from datetime import date
from uuid import UUID

from sqlalchemy import (
    Date,
    DateTime,
    Integer,
    Interval,
    Text,
    and_,
    case,
    cast,
    exists,
    func,
    literal,
    or_,
    select,
    true,
    union_all,
)
from sqlalchemy.dialects.postgresql import JSONB, aggregate_order_by
from sqlalchemy.engine import Connection

from app.db.models import (
    BankCalendarYear,
    DayNote,
    IncomeRecord,
    IncomeSource,
    PaymentMethod,
    Transaction,
    TransactionItem,
)

methods = PaymentMethod.__table__
transactions = Transaction.__table__
items = TransactionItem.__table__
notes = DayNote.__table__
sources = IncomeSource.__table__
records = IncomeRecord.__table__
bank_years = BankCalendarYear.__table__


def month_start(day):
    return cast(func.date_trunc("month", cast(day, Date)), Date)


def month_shift(day, amount):
    return cast(day + func.make_interval(0, amount), Date)


def closing_date(month, closing_day):
    last = month_shift(month, 1) - 1
    return cast(
        month + cast(func.least(closing_day, func.extract("day", last)), Integer) - 1,
        Date,
    )


def period_statement(anchor_date: date, closing_day: int | None):
    anchor = literal(anchor_date, Date)
    month = month_start(anchor)
    if closing_day is None:
        start, end = month, month_shift(month, 1) - 1
    else:
        close = closing_date(month, closing_day)
        ending_month = case((anchor > close, month_shift(month, 1)), else_=month)
        start = closing_date(month_shift(ending_month, -1), closing_day) + 1
        end = closing_date(ending_month, closing_day)
    bounds = select(
        cast(start, Date).label("start_date"), cast(end, Date).label("end_date")
    ).cte()
    return select(
        bounds,
        (bounds.c.start_date - 1).label("previous_anchor_date"),
        (bounds.c.end_date + 1).label("next_anchor_date"),
    )


def find_card(connection: Connection, user_id: UUID, method_id: UUID):
    return (
        connection.execute(
            select(methods.c.closing_day).where(
                methods.c.id == method_id,
                methods.c.user_id == user_id,
                methods.c.type == "credit",
            )
        )
        .mappings()
        .one_or_none()
    )


def has_paycheck(connection: Connection, ledger_id: UUID) -> bool:
    return connection.scalar(
        select(
            exists().where(
                sources.c.ledger_id == ledger_id,
                sources.c.is_active.is_(True),
                sources.c.deleted_at.is_(None),
                sources.c.income_type == "paycheck",
            )
        )
    )


def calendar_available(day):
    return exists(select(1).where(bank_years.c.year == func.extract("year", day)))


def is_business_day(day):
    holiday = exists(
        select(1).where(
            bank_years.c.year == func.extract("year", day),
            cast(bank_years.c.holidays, JSONB).contains(
                func.jsonb_build_array(cast(day, Text))
            ),
        )
    )
    return and_(func.extract("isodow", day) <= 5, ~holiday)


def income_entries(ledger_id: UUID, start: date, end: date):
    # Continue beyond the window through the first business day: a payday after
    # end may shift back into the window. Missing calendars preserve the existing
    # income endpoint's unadjusted-date fallback, rather than assuming holidays.
    horizon = select((cast(literal(end, Date), Date) + 1).label("day")).cte(
        "horizon", recursive=True
    )
    horizon = horizon.union_all(
        select(horizon.c.day + 1).where(
            calendar_available(horizon.c.day),
            ~is_business_day(horizon.c.day),
        )
    )
    upper = select(func.max(horizon.c.day)).scalar_subquery()
    series = (
        func.generate_series(
            cast(literal(start, Date), DateTime),
            cast(upper, DateTime),
            cast(literal("1 day"), Interval),
        )
        .table_valued("value")
        .render_derived()
    )
    day = cast(series.c.value, Date)
    # Generate only window-sized candidates; no iteration from old rule anchors.
    recurring = or_(
        day == sources.c.next_expected_date,
        and_(
            sources.c.frequency == "biweekly",
            (day - sources.c.next_expected_date) % 14 == 0,
        ),
        and_(
            sources.c.frequency == "monthly",
            day
            == closing_date(
                month_start(day), func.extract("day", sources.c.reference_date)
            ),
        ),
    )
    candidates = (
        select(
            sources.c.id.label("income_source_id"),
            sources.c.income_type,
            sources.c.from_name,
            sources.c.payment_method_id,
            sources.c.expected_amount_cents.label("amount_cents"),
            sources.c.memo,
            day.label("expected_date"),
            day.label("display_date"),
        )
        .select_from(sources.join(series, true()))
        .where(
            sources.c.ledger_id == ledger_id,
            sources.c.is_active.is_(True),
            sources.c.deleted_at.is_(None),
            day >= sources.c.next_expected_date,
            recurring,
            # If next_expected_date was manually changed within its month, don't
            # manufacture a second monthly occurrence in that same month.
            or_(
                sources.c.frequency != "monthly",
                day == sources.c.next_expected_date,
                month_start(day) > month_start(sources.c.next_expected_date),
            ),
        )
        .cte("payday_walk", recursive=True)
    )
    candidates = candidates.union_all(
        select(
            candidates.c.income_source_id,
            candidates.c.income_type,
            candidates.c.from_name,
            candidates.c.payment_method_id,
            candidates.c.amount_cents,
            candidates.c.memo,
            candidates.c.expected_date,
            (candidates.c.display_date - 1).label("display_date"),
        ).where(
            candidates.c.income_type == "paycheck",
            calendar_available(candidates.c.display_date),
            ~is_business_day(candidates.c.display_date),
        )
    )
    resolved = case(
        (
            and_(
                candidates.c.income_type == "paycheck",
                ~calendar_available(candidates.c.display_date),
            ),
            candidates.c.expected_date,
        ),
        else_=candidates.c.display_date,
    )
    terminal = or_(
        candidates.c.income_type != "paycheck",
        ~calendar_available(candidates.c.display_date),
        is_business_day(candidates.c.display_date),
    )
    planned = select(
        literal("planned").label("status"),
        candidates.c.income_source_id,
        cast(literal(None), records.c.id.type).label("income_record_id"),
        candidates.c.income_type,
        candidates.c.from_name,
        candidates.c.payment_method_id,
        candidates.c.amount_cents,
        candidates.c.expected_date,
        cast(literal(None), Date).label("received_at"),
        resolved.label("display_date"),
        candidates.c.memo,
    ).where(terminal, resolved >= start, resolved <= end)
    received = select(
        literal("received").label("status"),
        records.c.income_source_id,
        records.c.id.label("income_record_id"),
        records.c.income_type,
        records.c.from_name,
        records.c.payment_method_id,
        records.c.amount_cents,
        records.c.expected_date,
        records.c.received_at,
        records.c.received_at.label("display_date"),
        records.c.memo,
    ).where(
        records.c.ledger_id == ledger_id,
        records.c.deleted_at.is_(None),
        records.c.received_at >= start,
        records.c.received_at <= end,
    )
    return union_all(planned, received).cte("income_entries")


def json_object(columns):
    return func.jsonb_build_object(
        *[
            part
            for key, value in columns.items()
            for part in (cast(literal(str(key), Text), Text), value)
        ]
    )


def json_array(value, *order):
    return func.coalesce(
        func.jsonb_agg(aggregate_order_by(value, *order)), cast(literal("[]"), JSONB)
    )


def method_json(table):
    return json_object(
        {name: table.c[name] for name in ("id", "name", "type", "color", "closing_day")}
    )


def calendar_statement(
    ledger_id: UUID,
    user_id: UUID,
    start: date,
    end: date,
    payment_method_id: UUID | None,
):
    wallet = select(methods).where(methods.c.user_id == user_id).cte("wallet")
    tx = (
        select(transactions)
        .where(
            transactions.c.ledger_id == ledger_id,
            transactions.c.deleted_at.is_(None),
            transactions.c.transacted_at >= start,
            transactions.c.transacted_at <= end,
            *(
                []
                if payment_method_id is None
                else [transactions.c.payment_method_id == payment_method_id]
            ),
        )
        .cte("calendar_transactions")
    )
    item_rows = (
        select(
            items.c.transaction_id,
            json_array(
                json_object(
                    {
                        name: items.c[name]
                        for name in ("id", "name", "category_id", "amount_cents")
                    }
                ),
                items.c.created_at,
                items.c.id,
            ).label("items"),
        )
        .where(
            items.c.transaction_id.in_(select(tx.c.id)),
        )
        .group_by(items.c.transaction_id)
        .cte("transaction_items")
    )
    tx_json = json_object(
        {
            **{
                name: tx.c[name]
                for name in (
                    "id",
                    "ledger_id",
                    "payment_method_id",
                    "merchant",
                    "transacted_at",
                    "memo",
                    "source",
                    "total_cents",
                    "tax_cents",
                    "tip_cents",
                )
            },
            "items": func.coalesce(item_rows.c["items"], cast(literal("[]"), JSONB)),
        }
    )
    daily_tx = (
        select(
            tx.c.transacted_at.label("date"),
            json_array(tx_json, tx.c.id).label("transactions"),
            func.sum(tx.c.total_cents).label("spending_cents"),
        )
        .select_from(tx.outerjoin(item_rows, tx.c.id == item_rows.c.transaction_id))
        .group_by(tx.c.transacted_at)
        .cte("daily_transactions")
    )
    counts = (
        select(
            tx.c.transacted_at.label("date"),
            tx.c.payment_method_id,
            func.count().label("transaction_count"),
        )
        .group_by(tx.c.transacted_at, tx.c.payment_method_id)
        .cte("counts")
    )
    daily_dots = (
        select(
            counts.c.date,
            json_array(
                json_object(
                    {
                        "payment_method_id": counts.c.payment_method_id,
                        "label": func.coalesce(wallet.c.name, "Unknown payment method"),
                        "color": wallet.c.color,
                        "transaction_count": counts.c.transaction_count,
                    }
                ),
                counts.c.payment_method_id,
            ).label("dots"),
        )
        .select_from(
            counts.outerjoin(wallet, wallet.c.id == counts.c.payment_method_id),
        )
        .group_by(counts.c.date)
        .cte("daily_dots")
    )
    income = income_entries(ledger_id, start, end)
    daily_income = (
        select(
            income.c.display_date.label("date"),
            json_array(
                json_object({c.name: c for c in income.c}),
                income.c.status,
                income.c.income_source_id,
                income.c.income_record_id,
                income.c.expected_date,
            ).label("income"),
            func.sum(
                case((income.c.status == "received", income.c.amount_cents), else_=0)
            ).label("received_income_cents"),
        )
        .group_by(income.c.display_date)
        .cte("daily_income")
    )
    series = (
        func.generate_series(
            cast(literal(start, Date), DateTime),
            cast(literal(end, Date), DateTime),
            cast(literal("1 day"), Interval),
        )
        .table_valued("value")
        .render_derived()
    )
    dates = select(cast(series.c.value, Date).label("date")).cte("dates")
    closings = (
        select(
            dates.c.date,
            json_array(method_json(wallet), wallet.c.id).label("closing_cards"),
        )
        .select_from(
            dates.join(
                wallet,
                and_(
                    wallet.c.type == "credit",
                    dates.c.date
                    == closing_date(month_start(dates.c.date), wallet.c.closing_day),
                ),
            ),
        )
        .group_by(dates.c.date)
        .cte("closings")
    )
    active_notes = (
        select(notes)
        .where(
            notes.c.ledger_id == ledger_id,
            notes.c.note_date >= start,
            notes.c.note_date <= end,
            func.btrim(notes.c.content) != "",
        )
        .cte("active_notes")
    )
    joined = (
        dates.outerjoin(daily_tx, dates.c.date == daily_tx.c.date)
        .outerjoin(daily_dots, dates.c.date == daily_dots.c.date)
        .outerjoin(daily_income, dates.c.date == daily_income.c.date)
        .outerjoin(closings, dates.c.date == closings.c.date)
        .outerjoin(active_notes, dates.c.date == active_notes.c.note_date)
    )
    empty = cast(literal("[]"), JSONB)
    daily = (
        select(
            dates.c.date,
            func.coalesce(daily_tx.c.transactions, empty).label("transactions"),
            func.coalesce(daily_dots.c.dots, empty).label("dots"),
            func.coalesce(daily_income.c.income, empty).label("income"),
            func.coalesce(closings.c.closing_cards, empty).label("closing_cards"),
            case(
                (
                    active_notes.c.id.is_not(None),
                    json_object(
                        {
                            name: active_notes.c[name]
                            for name in ("id", "ledger_id", "note_date", "content")
                        }
                    ),
                ),
                else_=None,
            ).label("note"),
            func.coalesce(daily_tx.c.spending_cents, 0).label("spending_cents"),
            func.coalesce(daily_income.c.received_income_cents, 0).label(
                "received_income_cents"
            ),
        )
        .select_from(joined)
        .cte("daily")
    )
    return select(
        select(json_array(method_json(wallet), wallet.c.id))
        .scalar_subquery()
        .label("payment_methods"),
        select(json_array(method_json(wallet), wallet.c.id))
        .where(wallet.c.type == "credit")
        .scalar_subquery()
        .label("cards"),
        select(json_array(json_object({c.name: c for c in daily.c}), daily.c.date))
        .scalar_subquery()
        .label("days"),
    )
