from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.receipts.schemas import ReceiptData, ReceiptItem
from app.receipts.validator import validate_receipt


def test_money_schema_avoids_decimal_regex_and_preserves_exact_amounts():
    schema = ReceiptItem.model_json_schema()
    assert schema["properties"]["price"]["type"] == "string"
    assert "pattern" not in schema["properties"]["price"]

    receipt = ReceiptData.model_validate({
        "merchant": "Market", "date": "2026-10-01", "currency": "USD",
        "items": [
            {"name": "Purchase", "price": "10.20", "category": "Food"},
            {"name": "Return", "price": "-0.55", "category": "Etc"},
        ],
        "tax": "0.88", "tip": "0", "total": "10.53",
    })

    assert receipt.items[1].price == Decimal("-0.55")
    assert receipt.model_dump(mode="json")["total"] == "10.53"
    assert validate_receipt(receipt).status == "pass"


def test_money_still_rejects_invalid_decimal_strings():
    with pytest.raises(ValidationError):
        ReceiptItem(name="Purchase", price="unknown", category="Food")
