import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dotenv import load_dotenv
from openai import OpenAIError

from app.receipts.parser import parse_receipt
from app.receipts.validator import validate_receipt


# uv run python scripts/test_receipt.py samples/receipt_01.jpg --output outputs/result.json
def main():
    # argparse: 터미널에서 실행할 때 전달한 인자를 읽어주는 Python 기본 라이브러리
    parser = argparse.ArgumentParser(description="Receipt image to validated JSON")
    parser.add_argument("image", type=Path)
    parser.add_argument("--output", type=Path)
    # args.image
    # args.output
    args = parser.parse_args()

    load_dotenv()
    
    try:
        # receipt: 이미지 전처리 및 LLM 호출
        receipt = parse_receipt(args.image)
        # report: parsing 결과 검증
        report = validate_receipt(receipt)

        result = {"receipt": receipt.model_dump(mode="json"), "validation": report.model_dump(mode="json")}
        output = args.output or Path("outputs") / (args.image.stem + ".json")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Status: {report.status} | items: {report.item_count} | difference: {report.difference}")
        print(f"Output: {output}")
        if report.issues:
            print("Issues: " + "; ".join(report.issues))
        return 0 if report.status == "pass" else 2
    except (OpenAIError, OSError, ValueError, RuntimeError) as exc:
        print(f"Parsing failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
