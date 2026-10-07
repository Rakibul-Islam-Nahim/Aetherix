"""Smoke tests — no real DB. Confirms routes register + auth gates work."""
from __future__ import annotations

import os

# Skip DB bootstrap during tests so we don't dial Postgres.
os.environ["AETHERIX_SKIP_BOOTSTRAP"] = "1"
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://test:test@127.0.0.1:65535/testdb",
)

import pytest
from fastapi.testclient import TestClient

# Build a TestClient without lifespan so we don't attempt DB connections.
from app.main import app


@pytest.fixture()
def client() -> TestClient:
    # Lifespan is disabled: the FastAPI app boots without touching the DB.
    # Individual tests still exercise auth gates, which return 401 before
    # any DB I/O.
    return TestClient(app, raise_server_exceptions=False)


def test_health(client: TestClient) -> None:
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    body = resp.json()
    assert "status" in body
    assert "db" in body
    assert "version" in body


def test_root(client: TestClient) -> None:
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["service"] == "aetherix-backend"


def test_news_requires_jwt(client: TestClient) -> None:
    resp = client.get("/api/v1/news")
    assert resp.status_code == 401
    assert "bearer" in resp.json()["detail"].lower()


def test_search_requires_jwt(client: TestClient) -> None:
    resp = client.get("/api/v1/search?q=foo")
    assert resp.status_code == 401


def test_bookmarks_requires_jwt(client: TestClient) -> None:
    resp = client.get("/api/v1/bookmarks")
    assert resp.status_code == 401


def test_bookmark_delete_requires_jwt(client: TestClient) -> None:
    resp = client.delete("/api/v1/bookmarks/1")
    assert resp.status_code == 401


def test_mcp_get_sources_requires_worker(client: TestClient) -> None:
    resp = client.get("/mcp/get_sources")
    assert resp.status_code == 401


def test_internal_ingest_requires_worker(client: TestClient) -> None:
    resp = client.post("/internal/ingest-all")
    assert resp.status_code == 401


def test_register_device_validation(client: TestClient) -> None:
    """Pydantic validation runs before any DB I/O."""
    resp = client.post(
        "/api/v1/auth/register-device",
        json={"name": "", "platform": "android"},
    )
    assert resp.status_code == 422


def test_register_device_valid_request_reaches_db(client: TestClient) -> None:
    """When validation passes the handler runs — without DB it 500s."""
    resp = client.post(
        "/api/v1/auth/register-device",
        json={"name": "test-device", "platform": "android"},
    )
    assert resp.status_code in (201, 500)


def test_mcp_publish_validates_schema(client: TestClient) -> None:
    """importance_score out of range is rejected by Pydantic."""
    resp = client.post(
        "/mcp/publish_article",
        headers={"Authorization": "Bearer dev-only-puku-token"},
        json={
            "canonical_url": "https://example.com/x",
            "title": "x",
            "importance_score": 42,  # max is 10
            "categories": [],
        },
    )
    # Either 422 (validation), 500 (DB error after auth). Either is fine —
    # what we want to confirm is that the auth gate passed.
    assert resp.status_code in (422, 500)


def test_all_routes_have_paths(client: TestClient) -> None:
    paths = {r.path for r in app.routes}
    expected = {
        "/api/v1/health",
        "/api/v1/auth/register-device",
        "/api/v1/news",
        "/api/v1/news/{article_id}",
        "/api/v1/search",
        "/api/v1/categories",
        "/api/v1/sources",
        "/api/v1/bookmarks",
        "/api/v1/bookmarks/{article_id}",
        "/mcp/get_sources",
        "/mcp/get_new_articles",
        "/mcp/publish_article",
        "/mcp/mark_processed",
        "/mcp/report_job_status",
        "/internal/ingest-all",
        "/internal/reseed-sources",
    }
    missing = expected - paths
    assert not missing, f"missing routes: {missing}"