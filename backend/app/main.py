from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.categories.router import router as categories_router
from app.core.config import settings
from app.day_notes.router import router as day_notes_router
from app.income.router import router as income_router
from app.ledgers.router import router as ledgers_router
from app.payment_methods.router import router as payment_methods_router
from app.transactions.router import router as transaction_router
from app.users.router import router as users_router

# API 인스턴스와 공통 미들웨어를 구성한다. 기능별 라우터는 별도로 등록한다.
app = FastAPI(
    title="Spending Tracker API",
    version="0.1.0",
)

# 허용된 프론트엔드 출처의 요청만 브라우저 CORS 검사를 통과시킨다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_origin],
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# 사용자 프로필 초기화 API를 앱에 연결한다.
app.include_router(users_router)
# 인증된 사용자의 가계부 목록 API를 앱에 연결한다.
app.include_router(ledgers_router)
# 가계부 선택과 무관한 사용자 지갑 API를 연결한다.
app.include_router(payment_methods_router)
# 인증된 사용자가 공통 카테고리 목록을 조회하는 API를 연결한다.
app.include_router(categories_router)
# 가계부 멤버의 수동 지출 입력 API를 연결한다.
app.include_router(transaction_router)
# 가계부 멤버의 수입 기록 API를 연결한다.
app.include_router(income_router)
# 가계부별 하루 메모 기록 API를 연결한다
app.include_router(day_notes_router)

@app.get("/health/live")
async def health_live() -> dict[str, str]:
    """DB 연결과 무관하게 API 프로세스가 응답하는지 확인한다."""
    return {"status": "ok"}
