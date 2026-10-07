"""Minimal smoke tests — no real DB. Hit /api/v1/health on a test client."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app)


def test_health(client: TestClient) -> None:
    # In a fresh container without postgres, the health endpoint still
    # responds, just with db=false. We only assert the route exists.
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    body = resp.json()
    assert "status" in body
    assert "db" in body
    assert "version" in body