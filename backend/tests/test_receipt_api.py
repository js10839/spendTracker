import base64
import io
from unittest.mock import MagicMock, Mock

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from openai import APITimeoutError
from PIL import Image
from pydantic import SecretStr

from app.main import app
from app.receipts import parser, router, service
from app.receipts.parser import MAX_FILE_BYTES, prepare_image
from app.receipts.schemas import ReceiptData
from app.receipts.validator import validate_receipt


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def receipt(total="10.00"):
    return ReceiptData.model_validate({
        "merchant": "Market", "date": "2026-11-11", "currency": "USD",
        "location": "123 Main St, New York, NY 10001",
        "items": [{"name": "Bread", "price": "10.00", "category": "Food"}],
        "tax": "0", "tip": "0", "total": total,
    })


@pytest.mark.parametrize("total,status", [("10.00", "pass"), ("12.00", "review")])
def test_parse_returns_receipt_and_validation(client, monkeypatch, total, status):
    data = receipt(total)
    parse = Mock(return_value=service.ReceiptParseResponse(
        receipt=data, validation=validate_receipt(data),
    ))
    monkeypatch.setattr(router, "parse_uploaded_receipt", parse)
    response = client.post("/receipts/parse", files={"file": ("receipt.png", b"image", "image/png")})
    assert response.status_code == 200
    assert response.json()["receipt"]["total"] == total
    assert response.json()["receipt"]["location"] == data.location
    assert response.json()["validation"]["status"] == status
    parse.assert_called_once_with(b"image")


@pytest.mark.parametrize("image,status", [(b"", 422), (b"x" * (MAX_FILE_BYTES + 1), 413)])
def test_rejects_empty_or_large_upload(client, monkeypatch, image, status):
    parse = Mock()
    monkeypatch.setattr(router, "parse_uploaded_receipt", parse)
    response = client.post("/receipts/parse", files={"file": ("receipt.png", image)})
    assert response.status_code == status
    parse.assert_not_called()


def test_missing_upload(client):
    assert client.post("/receipts/parse").status_code == 422


def test_parse_has_no_security_requirement():
    operation = app.openapi()["paths"]["/receipts/parse"]["post"]
    assert not operation.get("security")


def test_prepare_uploaded_image():
    output = io.BytesIO()
    Image.new("RGBA", (10, 10), (0, 0, 0, 0)).save(output, format="PNG")
    assert prepare_image(output.getvalue()).startswith("data:image/jpeg;base64,")
    with pytest.raises(ValueError, match="Invalid image"):
        prepare_image(b"not an image")


def test_rejects_images_over_pixel_limit(monkeypatch):
    monkeypatch.setattr(parser, "MAX_PIXELS", 100)
    output = io.BytesIO()
    Image.new("RGB", (11, 10), "white").save(output, format="PNG")
    with pytest.raises(ValueError, match="Image pixel count too large"):
        prepare_image(output.getvalue())


@pytest.mark.parametrize("size", [(10, 10), (5712, 4284)])
def test_upload_runs_parser_and_validation(client, monkeypatch, size):
    monkeypatch.setattr(service.settings, "openai_api_key", SecretStr("test-key"))
    provider = MagicMock()
    provider.return_value.__enter__.return_value.responses.parse.return_value.output_parsed = receipt()
    monkeypatch.setattr(service, "OpenAI", provider)
    output = io.BytesIO()
    Image.new("RGB", size, "white").save(output, format="PNG")

    response = client.post("/receipts/parse", files={"file": ("receipt.png", output.getvalue())})

    assert response.status_code == 200
    assert response.json()["validation"]["status"] == "pass"
    assert response.json()["receipt"]["location"] == receipt().location
    request = provider.return_value.__enter__.return_value.responses.parse.call_args.kwargs
    assert request["input"][0]["content"][0]["image_url"].startswith("data:image/jpeg;base64,")
    encoded = request["input"][0]["content"][0]["image_url"].split(",", 1)[1]
    with Image.open(io.BytesIO(base64.b64decode(encoded))) as prepared:
        assert prepared.format == "JPEG"
        assert max(prepared.size) <= 2200
    assert request["store"] is False
    provider.return_value.__exit__.assert_called_once()


@pytest.mark.parametrize("error,status", [
    (ValueError("private input"), 422),
    (RuntimeError("private output"), 502),
    (APITimeoutError(request=httpx.Request("POST", "https://example.com")), 504),
])
def test_service_maps_errors_without_exposing_details(monkeypatch, error, status):
    monkeypatch.setattr(service.settings, "openai_api_key", SecretStr("test-key"))
    api = MagicMock()
    monkeypatch.setattr(service, "OpenAI", api)
    monkeypatch.setattr(service, "parse_receipt", Mock(side_effect=error))
    with pytest.raises(HTTPException) as result:
        service.parse_uploaded_receipt(b"image")
    assert result.value.status_code == status
    assert "private" not in result.value.detail
    api.return_value.__exit__.assert_called_once()


def test_missing_key_returns_service_unavailable(monkeypatch):
    monkeypatch.setattr(service.settings, "openai_api_key", None)
    with pytest.raises(HTTPException) as result:
        service.parse_uploaded_receipt(b"image")
    assert result.value.status_code == 503
