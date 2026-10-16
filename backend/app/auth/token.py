from functools import lru_cache
from uuid import UUID

import jwt
from fastapi import HTTPException, status
from jwt import PyJWKClient, PyJWTError

from app.core.config import settings


@lru_cache
def _jwks_client(url: str) -> PyJWKClient:
    """서명 검증용 JWKS 클라이언트를 URL별로 재사용한다."""
    return PyJWKClient(url, timeout=5)


def verify_access_token(token: str) -> UUID:
    """Supabase JWT를 검증하고 토큰의 sub를 사용자 UUID로 반환한다."""
    if not settings.supabase_url:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase Auth is not configured",
        )

    issuer = f"{settings.supabase_url.rstrip('/')}/auth/v1"
    jwks_url = settings.supabase_jwks_url or f"{issuer}/.well-known/jwks.json"

    try:
        key = _jwks_client(jwks_url).get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            key.key,
            algorithms=["RS256", "ES256"],
            audience="authenticated",
            issuer=issuer,
            options={"require": ["exp", "sub", "aud", "iss"]},
        )
        if claims.get("role") != "authenticated":
            raise ValueError("Unexpected token role")
        # sub는 Supabase Auth의 auth.users.id이며 여기서 새 UUID를 만들지 않는다.
        return UUID(claims["sub"])
    except (PyJWTError, ValueError, TypeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
