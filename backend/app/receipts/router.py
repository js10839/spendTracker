# Receive and process actual API requests
# - Excute API requests
# - Swagger
from typing import Annotated

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.receipts.parser import MAX_FILE_BYTES
from app.receipts.service import ReceiptParseResponse, parse_uploaded_receipt

# 이 라우터의 모든 주소 앞에 /receipts 추가, swagger에서 receipts 그룹으로 표시
router = APIRouter(prefix="/receipts", tags=["receipts"])

# receipts/parse
# response_model은 반환 데이터를 ReceiptParseResponse구조로 검증
@router.post("/parse", response_model=ReceiptParseResponse)
def parse_receipt_image(
    file: Annotated[
        UploadFile, 
        File(description="JPEG, PNG, WEBP or MPO; up to 10 MiB")
    ],
) -> ReceiptParseResponse:
    """영수증 이미지를 파싱하고 금액 검증 결과를 반환한다. DB에는 저장하지 않는다."""

    # 파일을 bytes로 로드
    image = file.file.read(MAX_FILE_BYTES + 1)

    # 413: 파일 크기 초과 에러
    if len(image) > MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds 10 MiB")
    # 422: 파일 없음 에러
    if not image:
        raise HTTPException(status_code=422, detail="Receipt image is empty")

    # 이미지 데이터를 service.py로 전달
    # 반환: {receipt, validation}
    return parse_uploaded_receipt(image)
