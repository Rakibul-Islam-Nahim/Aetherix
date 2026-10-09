"""Monthly retention job.

Deletes every article whose ``published_at`` is before the 1st of
the current month, except for articles that are still referenced by
at least one Bookmark. Bookmarks keep their article alive
indefinitely — the user can read them until the user (or an admin)
deletes the bookmark itself.

The job is idempotent: if nothing is older than the cut-off it is a
no-op. Safe to call from the API lifespan, the host cron, or the
``/admin/cleanup`` endpoint.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import delete, exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.logging import get_logger
from app.models.orm import Article, Bookmark

logger = get_logger("aetherix.cleanup")


def _cutoff(now: datetime | None = None) -> datetime:
    """First instant of the current calendar month (UTC).

    Anything with ``published_at < cutoff`` is fair game.
    """
    n = now or datetime.now(timezone.utc)
    return n.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


async def cleanup_old_articles(
    session: AsyncSession, *, dry_run: bool = False
) -> dict:
    """Delete every Article row whose ``published_at`` is before the
    1st of the current UTC month, except for rows still referenced by
    at least one Bookmark.

    Returns a small report so the caller (cron / admin endpoint /
    log) can show what happened.
    """
    cutoff = _cutoff()
    # "Has a bookmark" = there's a Bookmark row whose article_id == a.id.
    bookmarked = exists().where(Bookmark.article_id == Article.id)

    eligible = (
        select(Article.id)
        .where(Article.published_at.is_not(None))
        .where(Article.published_at < cutoff)
        .where(~bookmarked)
    )
    rows = (await session.execute(eligible)).scalars().all()
    eligible_ids = list(rows)

    if dry_run or not eligible_ids:
        logger.info(
            "cleanup_noop" if not eligible_ids else "cleanup_dry_run",
            cutoff=cutoff.isoformat(),
            eligible=len(eligible_ids),
        )
        return {
            "cutoff": cutoff.isoformat(),
            "eligible": len(eligible_ids),
            "deleted": 0,
            "dry_run": dry_run,
        }

    # Bulk delete in a single statement — fast and atomic.
    stmt = delete(Article).where(Article.id.in_(eligible_ids))
    result = await session.execute(stmt)
    await session.commit()

    deleted = result.rowcount or 0
    logger.info(
        "cleanup_done",
        cutoff=cutoff.isoformat(),
        eligible=len(eligible_ids),
        deleted=deleted,
    )
    return {
        "cutoff": cutoff.isoformat(),
        "eligible": len(eligible_ids),
        "deleted": deleted,
        "dry_run": False,
    }
