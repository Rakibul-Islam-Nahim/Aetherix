"""Pydantic v2 schemas exposed by the REST API and MCP."""
from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


# -------- health --------
class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    db: bool
    version: str = "0.1.0"


# -------- sources --------
class SourceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    url: HttpUrl
    type: str
    enabled: bool
    category: str | None
    last_checked_at: datetime | None
    created_at: datetime


# -------- categories --------
class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None


# -------- articles --------
class ArticleSummary(BaseModel):
    """List-row representation of an article."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    canonical_url: HttpUrl
    source_id: int
    importance_score: float | None
    processing_status: str
    published_at: datetime | None
    discovered_at: datetime
    # Primary (first) normalized tag from the Aetherix allowlist:
    # ``Cyber Security``, ``Technology``, ``AI``, ``Hacking``.
    # Kept flat on the summary so list rows can show it without an
    # extra fetch.
    tag: str | None = None


class ArticleDetail(ArticleSummary):
    author: str | None
    summary: str | None
    what_happened: str | None
    why_it_matters: str | None
    categories: list[CategoryOut] = Field(default_factory=list)
    source: SourceOut


class PublishedArticle(BaseModel):
    """Payload Puku sends to /mcp/publish_article."""
    canonical_url: HttpUrl
    source_external_id: int | None = None
    title: str
    author: str | None = None
    published_at: datetime | None = None
    summary: str | None = None
    what_happened: str | None = None
    why_it_matters: str | None = None
    importance_score: float | None = Field(default=None, ge=1, le=10)
    content_hash: str | None = None
    categories: list[str] = Field(default_factory=list)


class PublishAck(BaseModel):
    article_id: int
    created: bool
    status: str


# -------- bookmarks --------
class BookmarkIn(BaseModel):
    article_id: int


class BookmarkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    article_id: int
    created_at: datetime
    # Filled in by the list endpoint via a join with Article so the
    # client can render the bookmark row without a follow-up fetch.
    # Optional because the article may have been deleted by the
    # monthly retention job; in that case the bookmark itself is
    # removed by the cascade on the FK.
    article_title: str | None = None
    article_canonical_url: str | None = None


# -------- auth (Flutter devices) --------
class DeviceRegisterIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    platform: Literal["android", "windows", "ios", "web", "linux", "macos"]
    # Optional human-readable device model (e.g. "Pixel 7 Pro", "Galaxy S24").
    # Stored on the Device row so the admin panel can show "whose device".
    model: str | None = Field(default=None, max_length=120)


class DeviceRegisterOut(BaseModel):
    user_id: int
    access_token: str
    expires_in_minutes: int


# -------- admin --------
class AdminLoginIn(BaseModel):
    password: str = Field(min_length=1, max_length=200)


class AdminLoginOut(BaseModel):
    access_token: str
    expires_in_minutes: int


class DeviceAdminOut(BaseModel):
    """One row in the admin device list."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    platform: str
    model: str | None = None
    user_id: int
    username: str
    user_blocked: bool
    last_seen_at: datetime | None
    created_at: datetime


# -------- search --------
class SearchOut(BaseModel):
    """Search result row — same shape as list news."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    canonical_url: HttpUrl
    source_id: int
    importance_score: float | None
    processing_status: str
    published_at: datetime | None
    discovered_at: datetime
    # Primary normalized tag from the Aetherix allowlist. Same semantics
    # as ``ArticleSummary.tag``.
    tag: str | None = None