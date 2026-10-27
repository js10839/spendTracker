from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user_id
from app.db.models.ledger import Ledger
from app.db.session import get_db
from app.ledgers.dependencies import get_user_ledger
from app.transactions.schema import (
    ManualTransactionGroupCreate,
    TransactionGroupRead,
    TransactionGroupUpdate,
    TransactionSearchRead,
)
from app.transactions.service import (
    create_grouped_manual_transaction,
    list_ledger_transactions,
    search_ledger_transactions,
    soft_delete_transaction,
    update_transaction_group,
)

router = APIRouter(prefix="/ledgers/{ledger_id}/transactions", tags=["transactions"])

@router.post("", status_code=status.HTTP_201_CREATED, response_model=TransactionGroupRead)
def add_manual_transaction(data: ManualTransactionGroupCreate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> TransactionGroupRead:
    """가계부 접근 권한을 확인한 뒤 결제와 품목을 함께 생성한다."""
    return create_grouped_manual_transaction(db, ledger_id=ledger.id, user_id=user_id, data=data)

@router.get("", response_model=list[TransactionGroupRead])
def get_ledger_transactions(start_date: date, end_date: date, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> list[TransactionGroupRead]:
    """접근 가능한 가계부의 결제·품목과 계산된 총액을 반환한다."""
    return list_ledger_transactions(db, ledger_id=ledger.id, start_date=start_date, end_date=end_date)

@router.get("/search", response_model=TransactionSearchRead)
def search_transactions(query: Annotated[str, Query(min_length=1)], start_date: date, end_date: date, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)], payment_method_id: UUID | None = None) -> TransactionSearchRead:
    """가계부의 지정 기간에서 품목을 검색하고 선택한 카드로 좁힌다."""
    return search_ledger_transactions(db, ledger.id, start_date, end_date, query, payment_method_id)

@router.put("/{transaction_id}", response_model=TransactionGroupRead)
def put_transaction(transaction_id: UUID, data: TransactionGroupUpdate, ledger: Annotated[Ledger, Depends(get_user_ledger)], user_id: Annotated[UUID, Depends(get_current_user_id)], db: Annotated[Session, Depends(get_db)]) -> TransactionGroupRead:
    """가계부 접근 권한을 확인한 뒤 결제와 기존 품목을 수정한다."""
    return update_transaction_group(db, ledger_id=ledger.id, transaction_id=transaction_id, user_id=user_id, data=data)

@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction(transaction_id: UUID, ledger: Annotated[Ledger, Depends(get_user_ledger)], db: Annotated[Session, Depends(get_db)]) -> None:
    """가계부 접근 권한을 확인한 뒤 거래 전체를 숨긴다."""
    soft_delete_transaction(db, ledger_id=ledger.id, transaction_id=transaction_id)
