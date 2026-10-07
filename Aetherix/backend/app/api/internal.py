"""Internal routes — bound to 127.0.0.1 only, never reachable from the internet.

Protected by the same PUKU_WORKER_TOKEN used by Puku MCP tools.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import DBSession
from app.core.logging import get_logger
from app.core.security import require_puku_worker
from app.models.orm import Source
from app.services import rss_service

router = APIRouter(prefix="/internal", tags=["internal"])
logger = get_logger(__name__)


@router.post("/ingest-all")
async def ingest_all(
    session: DBSession,
    _: bool = Depends(require_puku_worker),
) -> dict:
    """Walk every enabled Source, persist any new RSS entries.

    Cron triggers this every 15 minutes from the host. The worker token is
    shared with Puku so we don't mint a separate credential.
    """
    stmt = select(Source).where(Source.enabled.is_(True))
    sources = (await session.execute(stmt)).scalars().all()

    total_new = 0
    failed: list[str] = []
    for s in sources:
        try:
            new_entries = await rss_service.ingest_source(session, s)
            total_new += len(new_entries)
        except Exception as exc:  # noqa: BLE001
            failed.append(f"{s.name}: {exc.__class__.__name__}: {exc}")
            logger.warning("rss_ingest_failed", source=s.name, error=str(exc))

    await session.commit()
    logger.info(
        "rss_ingest_all_done",
        sources_polled=len(sources),
        new_articles=total_new,
        failed=len(failed),
    )
    return {
        "sources_polled": len(sources),
        "new_articles": total_new,
        "failed": failed,
    }


@router.post("/reseed-sources")
async def reseed_sources(
    session: DBSession,
    _: bool = Depends(require_puku_worker),
) -> dict:
    """Manually trigger seeding of default_sources.json.

    Useful if you added a source to the JSON and want it picked up without
    restarting the backend.
    """
    from app.services import seed_service

    inserted = await seed_service.seed_default_sources(session)
    await session.commit()
    return {"inserted": inserted}