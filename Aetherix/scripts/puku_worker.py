#!/usr/bin/env python3
"""Aetherix Puku worker (Python stand-in).

Runs the full Puku loop against the local backend:

    1. GET  /mcp/get_new_articles
    2. For each article: fetch the URL, ask the LLM, POST /mcp/publish_article
    3. POST /mcp/report_job_status

This is a stand-in until the real Puku CLI is published. Drop the real
binary at /usr/local/bin/puku on the VPS and remove this script from
the cron entry.

Configuration is read from environment variables:

    AETHERIX_BACKEND_URL   default: http://127.0.0.1:8000
    AETHERIX_WORKER_TOKEN  default: <required, no default>
    OPENAI_API_KEY         default: <required for summarization>

The summarization step is intentionally simple — a single prompt to
gpt-4o-mini. Replace `summarize()` with whatever model you prefer.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from typing import Any

import feedparser  # noqa: F401  (only used as fallback in summarize)
import httpx

DEFAULT_BACKEND = "http://127.0.0.1:8000"


def log(msg: str) -> None:
    print(f"[puku {datetime.now(timezone.utc).isoformat()}] {msg}", flush=True)


def backend_get(path: str, token: str, base: str) -> dict[str, Any]:
    r = httpx.get(
        f"{base}{path}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=30.0,
    )
    r.raise_for_status()
    return r.json()


def backend_post(
    path: str, token: str, base: str, payload: dict[str, Any]
) -> dict[str, Any]:
    r = httpx.post(
        f"{base}{path}",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=60.0,
    )
    r.raise_for_status()
    return r.json()


def fetch_article_body(url: str) -> str:
    """Pull the raw article text. Best-effort — failures fall back to ''."""
    try:
        r = httpx.get(
            url,
            follow_redirects=True,
            timeout=20.0,
            headers={"User-Agent": "AetherixPuku/0.1"},
        )
        r.raise_for_status()
        text = re.sub(r"<[^>]+>", " ", r.text)
        text = re.sub(r"\s+", " ", text).strip()
        return text[:8000]
    except Exception as exc:  # noqa: BLE001
        log(f"fetch failed for {url}: {exc.__class__.__name__}: {exc}")
        return ""


def summarize(title: str, body: str, source_name: str) -> dict[str, Any]:
    """Ask the LLM to fill the canonical Aetherix summary schema.

    Falls back to a stub if OPENAI_API_KEY isn't set, so the loop still
    runs end-to-end in dev.
    """
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        log("OPENAI_API_KEY missing — returning stub summary")
        return _stub_summary(title, source_name)

    system = (
        "You are TechNewsAgent, the AI worker for Aetherix. Read one article "
        "and respond with ONLY valid JSON matching this schema:\n"
        '{"summary": "...", "what_happened": "...", "why_it_matters": "...", '
        '"importance_score": 1-10, "categories": ["..."]}. '
        "Be concise, neutral, and accurate. No emojis, no marketing tone."
    )
    user = f"Source: {source_name}\nTitle: {title}\n\nBody:\n{body}"

    try:
        r = httpx.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "gpt-4o-mini",
                "temperature": 0.2,
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
            },
            timeout=60.0,
        )
        r.raise_for_status()
        content = r.json()["choices"][0]["message"]["content"]
        parsed = json.loads(content)
        return {
            "summary": parsed.get("summary", ""),
            "what_happened": parsed.get("what_happened", ""),
            "why_it_matters": parsed.get("why_it_matters", ""),
            "importance_score": _clamp_score(parsed.get("importance_score")),
            "categories": parsed.get("categories", []),
        }
    except Exception as exc:  # noqa: BLE001
        log(f"LLM call failed: {exc.__class__.__name__}: {exc}")
        return _stub_summary(title, source_name)


def _stub_summary(title: str, source_name: str) -> dict[str, Any]:
    return {
        "summary": f"Stub summary for '{title}' from {source_name}.",
        "what_happened": "No OPENAI_API_KEY configured — set one to enable real summarization.",
        "why_it_matters": "Stub run so the worker loop still exercises the MCP contract end-to-end.",
        "importance_score": 1,
        "categories": [],
    }


def _clamp_score(raw: Any) -> int:
    try:
        n = int(raw)
        return max(1, min(10, n))
    except (TypeError, ValueError):
        return 1


def content_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def run(token: str, base: str, dry_run: bool) -> int:
    started_at = datetime.now(timezone.utc)
    log(f"start dry_run={dry_run} backend={base}")

    try:
        pending = backend_get("/mcp/get_new_articles?limit=50", token, base).get(
            "articles", []
        )
    except Exception as exc:  # noqa: BLE001
        log(f"get_new_articles failed: {exc.__class__.__name__}: {exc}")
        _report(token, base, started_at, 0, 0, 1, str(exc))
        return 2

    found = len(pending)
    processed = 0
    failed = 0
    for art in pending:
        canonical_url = art["canonical_url"]
        title = art.get("title", "(untitled)")
        source_name = art.get("source_name", "unknown")

        try:
            body = "" if dry_run else fetch_article_body(canonical_url)
            summary = summarize(title, body, source_name)
            payload = {
                "canonical_url": canonical_url,
                "title": title,
                "source_external_id": art.get("source_id"),
                "summary": summary["summary"],
                "what_happened": summary["what_happened"],
                "why_it_matters": summary["why_it_matters"],
                "importance_score": summary["importance_score"],
                "content_hash": content_hash(body or title),
                "categories": summary["categories"],
            }
            if not dry_run:
                backend_post("/mcp/publish_article", token, base, payload)
            else:
                log(f"dry-run: would publish {canonical_url}")
            processed += 1
        except Exception as exc:  # noqa: BLE001
            failed += 1
            log(f"article failed: {canonical_url}: {exc.__class__.__name__}: {exc}")

    _report(token, base, started_at, found, processed, failed, None)
    log(f"done found={found} processed={processed} failed={failed}")
    return 0 if failed == 0 else 1


def _report(
    token: str,
    base: str,
    started_at: datetime,
    found: int,
    processed: int,
    failed: int,
    error: str | None,
) -> None:
    payload = {
        "started_at": started_at.isoformat(),
        "finished_at": datetime.now(timezone.utc).isoformat(),
        "status": "OK" if failed == 0 else "PARTIAL",
        "articles_found": found,
        "articles_processed": processed,
        "articles_failed": failed,
        "error": error,
    }
    try:
        backend_post("/mcp/report_job_status", token, base, payload)
    except Exception as exc:  # noqa: BLE001
        log(f"report_job_status failed: {exc.__class__.__name__}: {exc}")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--base", default=os.environ.get("AETHERIX_BACKEND_URL", DEFAULT_BACKEND))
    p.add_argument("--token", default=os.environ.get("AETHERIX_WORKER_TOKEN"))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    if not args.token:
        log("AETHERIX_WORKER_TOKEN is required")
        return 2
    return run(args.token, args.base, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())