"""영수증 이미지 파싱과 검증 결과를 함께 제공한다."""

from fastapi import HTTPException
from openai import APITimeoutError, OpenAI, OpenAIError
from pydantic import BaseModel, ValidationError

from app.core.config import settings
from app.receipts.parser import parse_receipt
from app.receipts.schemas import ReceiptData
from app.receipts.validator import ValidationReport, validate_receipt

# 반환: {receipt, validation}
class ReceiptParseResponse(BaseModel):
    receipt: ReceiptData
    validation: ValidationReport


def parse_uploaded_receipt(image: bytes) -> ReceiptParseResponse:
    # 503: NOT OPEN_API_KEY
    if settings.openai_api_key is None:
        raise HTTPException(status_code=503, detail="OPEN_API_KEY is not configured")

    # Call OpenAI in parser.py
    try:
        with OpenAI(
            api_key=settings.openai_api_key.get_secret_value(),
            timeout=30.0,
            max_retries=0,
        ) as client:
            receipt = parse_receipt(image, client=client)

    # 504: OpenAI 응답 시간 초과
    except APITimeoutError as exc:
        raise HTTPException(status_code=504, detail="Receipt parsing timed out") from exc
    # 502: OpenAI 오류, 파싱 결과 오류
    except (OpenAIError, ValidationError, RuntimeError) as exc:
        raise HTTPException(status_code=502, detail="Could not parse receipt") from exc
    # 422: 잘못되거나 지원하지 않은 이미지
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Invalid or unsupported receipt image") from exc

    return ReceiptParseResponse(receipt=receipt, validation=validate_receipt(receipt))
