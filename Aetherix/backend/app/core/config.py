"""Centralised settings loaded from environment variables.

All secrets come from env (docker compose passes them in from .env).
Never commit a real .env.
"""
from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Postgres
    database_url: str = Field(
        default="postgresql+asyncpg://aetherix:aetherix@localhost:5432/aetherix",
        alias="DATABASE_URL",
    )

    # JWT (Flutter user tokens)
    jwt_secret: str = Field(default="dev-only-change-me", alias="JWT_SECRET")
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = Field(default=43200, alias="JWT_EXPIRES_MINUTES")

    # Puku worker token (separate from Flutter users, per docs §35)
    puku_worker_token: str = Field(default="dev-only-puku-token", alias="PUKU_WORKER_TOKEN")

    # Admin panel password (separate from JWT — short-lived admin login)
    # Production deployments MUST set ADMIN_PASSWORD in .env. The
    # default below is a non-secret dev placeholder that the operator
    # is expected to override; it is intentionally not a real word.
    admin_password: str = Field(
        default="change_me_admin_password", alias="ADMIN_PASSWORD"
    )

    # Misc
    backend_public_url: str = Field(
        default="http://localhost:8000", alias="BACKEND_PUBLIC_URL"
    )
    log_level: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()