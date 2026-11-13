"""DB 카테고리로 영수증을 파싱하는 별도 실행 스크립트."""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv

load_dotenv()

from openai import OpenAI, OpenAIError
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionLocal
from app.receipts.parser import prepare_image
from app.receipts.prompts import SYSTEM_PROMPT
from app.receipts.schemas import ReceiptData
from app.receipts.schemas_DB import load_receipt_schema
from app.receipts.validator import validate_receipt


def parse_receipt(
    image_path: Path,
    *,
    db: Session,
    client: OpenAI | None = None,
    model: str | None = None,
) -> ReceiptData:
    receipt_schema = load_receipt_schema(db)
    image_url = prepare_image(image_path)

    def request(api: OpenAI) -> ReceiptData:
        response = api.responses.parse(
            model=model or settings.openai_receipt_model,
            instructions=SYSTEM_PROMPT,
            input=[{
                "role": "user",
                "content": [{
                    "type": "input_image",
                    "image_url": image_url,
                    "detail": "high",
                }],
            }],
            text_format=receipt_schema,
            max_output_tokens=4096,
            store=False,
        )
        if response.output_parsed is None:
            raise RuntimeError(
                "Model did not return a parsed receipt (refusal or incomplete output)"
            )
        return response.output_parsed

    if client is not None:
        return request(client)
    with OpenAI(timeout=30.0, max_retries=0) as api:
        return request(api)


# cd backend
# uv run python scripts/test_receipt_DB.py samples/receipt_01.jpg --output outputs/result_DB.json
def main() -> int:
    parser = argparse.ArgumentParser(description="Receipt image to JSON using DB category names")
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    try:
        with SessionLocal() as db:
            receipt = parse_receipt(args.image, db=db)
        report = validate_receipt(receipt)
        result = {
            "receipt": receipt.model_dump(mode="json"),
            "validation": report.model_dump(mode="json"),
        }
        output = args.output or Path("outputs") / (args.image.stem + "_DB.json")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

        print(
            f"Status: {report.status} | items: {report.item_count} | "
            f"difference: {report.difference} | location: {receipt.location}"
        )
        print(f"Output: {output}")
        if report.issues:
            print("Issues: " + "; ".join(report.issues))
        return 0 if report.status == "pass" else 2
    except SQLAlchemyError:
        # 접속 URL 등 비밀 정보가 들어갈 수 있는 DB 예외 원문은 출력하지 않는다.
        print("Parsing failed: could not load category names from the database", file=sys.stderr)
        return 1
    except (OpenAIError, OSError, ValueError, RuntimeError) as exc:
        print(f"Parsing failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
