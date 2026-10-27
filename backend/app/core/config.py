from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """환경 변수와 로컬 .env에서 백엔드 설정을 읽는다."""

    frontend_origin: str = "http://localhost:5173"
    db_url: str
    supabase_url: str | None = None
    supabase_jwks_url: str | None = None
    bankday_url: str = "https://bankday.dev/v1"
    bankday_key: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )


# 앱 전체에서 공유하는 설정 값이다. 비밀 값 자체를 로그에 출력하지 않는다.
settings = Settings()
