from uuid import UUID

import httpx

from app.core.config import settings


class AuthAdminUnavailable(Exception):
    """Supabase Auth 관리자 API를 사용할 수 없을 때 전달한다."""

async def delete_auth_user(user_id: UUID) -> None:
    """Supabase Auth에서 지정한 사용자를 비동기로 삭제한다."""
    ensure_auth_admin_configured()
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.delete(
                f"{settings.supabase_url.rstrip('/')}/auth/v1/admin/users/{user_id}",
                headers={"apikey": settings.supabase_secret_key},
                timeout=10.0,
            )
            # 다른 재시도에서 이미 삭제된 경우에도 같은 결과로 처리한다.
            if response.status_code == 404 and response.json().get("error_code") == "user_not_found":
                return
            response.raise_for_status()
    except (httpx.HTTPError, ValueError) as exc:
        raise AuthAdminUnavailable("Supabase Auth user deletion failed") from exc

def ensure_auth_admin_configured() -> None:
    """Supabase Auth 관리자 API에 필요한 설정을 확인한다."""
    if not settings.supabase_url or not settings.supabase_secret_key:
        raise AuthAdminUnavailable("Supabase Auth admin is not configured")

async def auth_user_exists(user_id: UUID) -> bool:
    """Supabase Auth에 사용자가 존재하는지 확인한다."""
    ensure_auth_admin_configured()

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{settings.supabase_url.rstrip('/')}/auth/v1/admin/users/{user_id}",
                headers={"apikey": settings.supabase_secret_key},
            )

            if response.status_code == 404 and response.json().get("error_code") == "user_not_found":
                return False

            response.raise_for_status()
            return True
    except (httpx.HTTPError, ValueError) as exc:
        raise AuthAdminUnavailable("Supabase Auth user lookup failed") from exc
