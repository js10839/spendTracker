"""앱 모델을 한곳에서 불러와 Alembic의 Base.metadata에 등록한다."""

from app.db.models.bank_calendar_year import BankCalendarYear
from app.db.models.category import Category
from app.db.models.day_note import DayNote
from app.db.models.income_record import IncomeRecord
from app.db.models.income_source import IncomeSource
from app.db.models.ledger import Ledger
from app.db.models.ledger_member import LedgerMember
from app.db.models.payment_method import PaymentMethod
from app.db.models.transaction import Transaction
from app.db.models.transaction_item import TransactionItem
from app.db.models.user import User

__all__ = [
    "BankCalendarYear",
    "Category",
    "DayNote",
    "IncomeRecord",
    "IncomeSource",
    "Ledger",
    "LedgerMember",
    "PaymentMethod",
    "Transaction",
    "TransactionItem",
    "User",
]
