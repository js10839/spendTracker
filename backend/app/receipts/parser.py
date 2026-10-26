# Reencoding image + call the Vision LLM

import base64
import io
import os
from pathlib import Path

from openai import OpenAI
from PIL import Image, ImageOps, UnidentifiedImageError

from .prompts import SYSTEM_PROMPT
from .schemas import ReceiptData

MAX_FILE_BYTES = 10 * 1024 * 1024
MAX_PIXELS = 24_000_000
MAX_EDGE = 2200

# 업로드 파일 검증 + 재인코딩
# 이미지를 문자열로 변환
def prepare_image(path: Path) -> str:
    # 경로 내 파일 없음
    if not path.is_file():
        raise ValueError(f"Image not found: {path}")
    # 파일 크기 제한
    if path.stat().st_size > MAX_FILE_BYTES:
        raise ValueError("Image exceeds 10 MB")
    try:
        with Image.open(path) as img:
            if img.format not in ("JPEG", "PNG", "WEBP", "MPO"): # 파일 검증
                raise ValueError("Only JPEG, PNG, WEBP, MPO supported")
            if img.width * img.height > MAX_PIXELS:
                raise ValueError("Image pixel count too large")
            img = ImageOps.exif_transpose(img)  # 메타데이터 제거
            img.thumbnail((MAX_EDGE, MAX_EDGE)) # 이미지 크기 축소
            rgb = Image.new("RGB", img.size, "white")
            # 투명도가 있는 사진인지 확인 
            #   -> 투명도가 있으면 흰 배경을 합성
            if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                rgba = img.convert("RGBA")
                rgb.paste(rgba, mask=rgba.getchannel("A"))
            else:
                rgb.paste(img.convert("RGB"))
            output = io.BytesIO()
            rgb.save(output, format="JPEG", quality=90)
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError("Invalid image") from exc
    # JPEG → Base64 Data URL
    # data URL:image format/jpeg;base64 encoding, data
    return ( 
        "data:image/jpeg;base64," 
        + base64.b64encode(output.getvalue()).decode("ascii")
    )

# Call LLM 
# parse_receipt(path, model="gpt-4.1")
# parse_receipt(path, client=my_client, model="gpt-4.1")    ->  Dependency Injection(의존성 주입)
# client는 api 요청을 수행하는 객체

# [Dependency Injection]
# : 함수 외부에서 client 설정을 한 곳에서 관리 가능함.
# my_client = OpenAI(
#     timeout=60.0,
#     max_retries=2
# )
#
# receipt1 = parse_receipt(path1, client=my_client)
# receipt2 = parse_receipt(path2, client=my_client)
def parse_receipt(
    image_path: Path,
    *,
    client: OpenAI | None = None,
    model: str | None = None
) -> ReceiptData:

    # load the img and reencoding into Data URL 
    image_url = prepare_image(image_path)

    # [Dependency Injection]
    # 함수 외부에서 client를 가져온 경우
    if client is not None:
        api = client
    # 함수 외부에서 client 정의가 없는 경우, 새로운 클라이언트 호출
    else:
        api = OpenAI(timeout=30.0, max_retries=0)

    # API를 호출하면서, 응답을 지정한 형태로 요청
    # OPENAI_RECEIPT_MODEL: .env에서 model 기본 값 변경 가능
    response = api.responses.parse(
        model=model or os.getenv(
            "OPENAI_RECEIPT_MODEL", "gpt-4.1-mini"
        ),
        instructions=SYSTEM_PROMPT,
        input=[{
            "role": "user",
            "content": [
                {
                    "type": "input_text",
                    "text": "Extract receipt data from this image."
                },
                {
                    "type": "input_image",
                    "image_url": image_url,
                    "detail": "high"
                },
            ]
        }],
        text_format=ReceiptData,
        max_output_tokens=4096,
        store=False,
    )

    if response.output_parsed is None:
        raise RuntimeError(
            "Model did not return a parsed receipt "
            "(refusal or incomplete output)"
        )

    return response.output_parsed
