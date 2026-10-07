"""MCP endpoint exposing tools Puku can call (per docs §19–§21).

Tools:
  * get_sources
  * get_new_articles
  * publish_article
  * mark_processed
  * report_job_status

All endpoints require the Puku worker token (separate from user JWT).
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import DBSession
from app.core.logging import get_logger
from app.core.security import require_puku_worker
from app.models.orm import Article, ProcessingJob, ProcessingStatus, Source
from app.repositories import article_repo
from app.schemas.dtos import PublishAck, PublishedArticle

router = APIRouter(prefix="/mcp", tags=["mcp-puku"])
logger = get_logger(__name__)


def _serialize_article_row(article: Article, source_name: str) -> dict[str, Any]:
    return {
        "id": article.id,
        "canonical_url": article.canonical_url,
        "title": article.title,
        "source_id": article.source_id,
        "source_name": source_name,
        "author": article.author,
        "published_at": article.published_at.isoformat() if article.published_at else None,
        "discovered_at": article.discovered_at.isoformat(),
        "summary_hint": article.summary,
    }


@router.get("/get_sources")
async def get_sources(
    session: DBSession,
    _: bool = Depends(require_puku_worker),
) -> dict[str, Any]:
    sources = await article_repo.list_enabled_sources(session)
    return {
        "sources": [
            {"id": s.id, "name": s.name, "url": s.url, "type": s.type, "category": s.category}
            for s in sources
        ]
    }


@router.get("/get_new_articles")
async def get_new_articles(
    session: DBSession,
    limit: int = 50,
    _: bool = Depends(require_puku_worker),
) -> dict[str, Any]:
    stmt = (
        select(Article)
        .where(Article.processing_status == ProcessingStatus.DISCOVERED.value)
        .order_by(Article.discovered_at.asc())
        .limit(limit)
    )
    articles = (await session.execute(stmt)).scalars().all()

    sources_by_id = {
        s.id: s.name for s in (await session.execute(select(Source))).scalars().all()
    }
    return {
        "articles": [
            _serialize_article_row(a, sources_by_id.get(a.source_id, "unknown"))
            for a in articles
        ]
    }


@router.post("/publish_article", response_model=PublishAck)
async def publish_article(
    payload: PublishedArticle,
    session: DBSession,
    _: bool = Depends(require_puku_worker),
) -> PublishAck:
    canonical_url = str(payload.canonical_url)

    # Map source by external id or fall back to a synthetic "puku" source
    source: Source | None = None
    if payload.source_external_id is not None:
        source = await session.get(Source, payload.source_external_id)
    if source is None:
        source = await article_repo.get_source_by_name(session, "puku-inbox")
        if source is None:
            source = Source(name="puku-inbox", url=canonical_url, type="puku")
            session.add(source)
            await session.flush()

    article, created = await article_repo.upsert_processed_article(
        session,
        canonical_url=canonical_url,
        title=payload.title,
        source=source,
        summary=payload.summary,
        what_happened=payload.what_happened,
        why_it_matters=payload.why_it_matters,
        importance_score=payload.importance_score,
        content_hash=payload.content_hash,
        categories=payload.categories,
        author=payload.author,
        published_at=payload.published_at,
    )
    await session.commit()
    logger.info(
        "puku_published",
        article_id=article.id,
        created=created,
        source=source.name,
    )
    return PublishAck(
        article_id=article.id,
        created=created,
        status=ProcessingStatus.PROCESSED.value,
    )


@router.post("/mark_processed")
async def mark_processed(
    body: dict[str, Any],
    session: DBSession,
    _: bool = Depends(require_puku_worker),
) -> dict[str, Any]:
    canonical_url = body.get("canonical_url")
    if not canonical_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="canonical_url required",
        )
    await article_repo.mark_processed(session, canonical_url)
    await session.commit()
    return {"ok": True}


@router.post("/report_job_status")
async def report_job_status(
    body: dict[str, Any],
    session: DBSession,
    _: bool = Depends(require_puku_worker),
) -> dict[str, Any]:
    job = ProcessingJob(
        started_at=datetime.fromisoformat(body["started_at"])
        if body.get("started_at")
        else datetime.now(timezone.utc),
        finished_at=datetime.fromisoformat(body["finished_at"])
        if body.get("finished_at")
        else datetime.now(timezone.utc),
        status=body.get("status", "OK"),
        articles_found=int(body.get("articles_found", 0)),
        articles_processed=int(body.get("articles_processed", 0)),
        articles_failed=int(body.get("articles_failed", 0)),
        error=body.get("error"),
    )
    session.add(job)
    await session.commit()
    return {"job_id": job.id}