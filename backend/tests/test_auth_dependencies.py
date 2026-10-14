from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Annotated
from uuid import UUID, uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.auth import token as token_module
from app.auth.dependencies import get_current_user_id

ISSUER = "https://example.supabase.co/auth/v1"


@pytest.fixture
def auth_client(monkeypatch: pytest.MonkeyPatch) -> tuple[TestClient, object]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    signing_key = SimpleNamespace(key=private_key.public_key())
    jwks_client = SimpleNamespace(get_signing_key_from_jwt=lambda _token: signing_key)
    monkeypatch.setattr(
        token_module.settings, "supabase_url", "https://example.supabase.co"
    )
    monkeypatch.setattr(token_module.settings, "supabase_jwks_url", None)
    monkeypatch.setattr(token_module, "_jwks_client", lambda _url: jwks_client)

    test_app = FastAPI()

    @test_app.get("/me")
    def me(user_id: Annotated[UUID, Depends(get_current_user_id)]) -> dict[str, str]:
        return {"id": str(user_id)}

    return TestClient(test_app), private_key


def make_token(private_key: object, **overrides: object) -> str:
    claims = {
        "sub": str(uuid4()),
        "iss": ISSUER,
        "aud": "authenticated",
        "role": "authenticated",
        "exp": datetime.now(UTC) + timedelta(minutes=5),
    }
    claims.update(overrides)
    return jwt.encode(claims, private_key, algorithm="RS256", headers={"kid": "test"})


def test_valid_access_token_returns_user_id(
    auth_client: tuple[TestClient, object],
) -> None:
    client, private_key = auth_client
    user_id = uuid4()
    response = client.get(
        "/me",
        headers={
            "Authorization": f"Bearer {make_token(private_key, sub=str(user_id))}"
        },
    )

    assert response.status_code == 200
    assert response.json() == {"id": str(user_id)}


def test_missing_bearer_token_is_rejected(
    auth_client: tuple[TestClient, object],
) -> None:
    client, _ = auth_client

    assert client.get("/me").status_code == 401


def test_invalid_signature_is_rejected(auth_client: tuple[TestClient, object]) -> None:
    client, _ = auth_client
    other_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    response = client.get(
        "/me", headers={"Authorization": f"Bearer {make_token(other_key)}"}
    )

    assert response.status_code == 401


@pytest.mark.parametrize(
    "claims",
    [
        {"iss": "https://other.supabase.co/auth/v1"},
        {"aud": "other"},
        {"role": "service_role"},
        {"sub": "not-a-uuid"},
        {"exp": datetime.now(UTC) - timedelta(minutes=1)},
    ],
)
def test_invalid_claims_are_rejected(
    auth_client: tuple[TestClient, object], claims: dict[str, object]
) -> None:
    client, private_key = auth_client
    access_token = make_token(private_key, **claims)

    response = client.get("/me", headers={"Authorization": f"Bearer {access_token}"})

    assert response.status_code == 401


def test_unconfigured_auth_fails_closed(
    auth_client: tuple[TestClient, object], monkeypatch: pytest.MonkeyPatch
) -> None:
    client, private_key = auth_client
    monkeypatch.setattr(token_module.settings, "supabase_url", None)

    response = client.get(
        "/me", headers={"Authorization": f"Bearer {make_token(private_key)}"}
    )

    assert response.status_code == 503
