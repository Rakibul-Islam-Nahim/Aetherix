"""RSS ingestion skeleton (Phase 2 placeholder).

Real implementation will:
  - pull feedparser entries
  - dedupe by canonical_url + content_hash
  - persist Article(processing_status=DISCOVERED)
  - return list of new articles for Puku to process
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

import feedparser
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.models.orm import Source, ProcessingStatus
from app.repositories import article_repo

logger = get_logger(__name__)


@dataclass(frozen=True)
class FeedEntry:
    canonical_url: str
    title: str
    author: str | None
    published_at: datetime | None
    summary: str | None


def _entry_datetime(entry) -> datetime | None:
    if getattr(entry, "published_parsed", None):
        import time
        return datetime.fromtimestamp(time.mktime(entry.published_parsed))
    return None


def fetch_feed_entries(source: Source) -> list[FeedEntry]:
    parsed = feedparser.parse(source.url)
    if parsed.bozo and not parsed.entries:
        logger.warning("rss_parse_failed", source=source.name, error=str(parsed.bozo_exception))
        return []
    out: list[FeedEntry] = []
    for e in parsed.entries:
        link = getattr(e, "link", None)
        if not link:
            continue
        out.append(
            FeedEntry(
                canonical_url=link,
                title=getattr(e, "title", "(untitled)"),
                author=getattr(e, "author", None),
                published_at=_entry_datetime(e),
                summary=getattr(e, "summary", None),
            )
        )
    return out


async def ingest_source(session: AsyncSession, source: Source) -> list[FeedEntry]:
    """Fetch + dedupe. New entries end up in DB with status DISCOVERED.

    Returns the list of *new* entries so Puku can pick them up.
    """
    new_entries: list[FeedEntry] = []
    for entry in fetch_feed_entries(source):
        existing = await article_repo.find_by_canonical(session, entry.canonical_url)
        if existing is not None:
            continue
        from app.models.orm import Article  # local to avoid cycle at import time
        article = Article(
            canonical_url=entry.canonical_url,
            url=entry.canonical_url,
            title=entry.title,
            source_id=source.id,
            author=entry.author,
            published_at=entry.published_at,
            processing_status=ProcessingStatus.DISCOVERED.value,
        )
        session.add(article)
        new_entries.append(entry)
    await article_repo.touch_source(session, source)
    await session.flush()
    logger.info("rss_ingest_done", source=source.name, new=len(new_entries))
    return new_entries