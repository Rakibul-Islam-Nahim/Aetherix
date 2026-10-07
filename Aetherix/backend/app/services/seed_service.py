"""Seed default_sources.json into the DB on first boot (or via /reseed)."""
from __future__ import annotations

import json
import pathlib

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.orm import Source


_SEEDS_PATH = pathlib.Path(__file__).resolve().parents[2] / "database" / "seeds" / "default_sources.json"


async def seed_default_sources(session: AsyncSession) -> int:
    """Insert any sources named in the JSON that don't yet exist.

    Returns the number of new sources inserted.
    """
    if not _SEEDS_PATH.exists():
        return 0
    raw = json.loads(_SEEDS_PATH.read_text(encoding="utf-8"))

    existing_names = set(
        (await session.execute(select(Source.name))).scalars().all()
    )

    inserted = 0
    for entry in raw:
        name = entry.get("name")
        if not name or name in existing_names:
            continue
        session.add(
            Source(
                name=name,
                url=entry["url"],
                type=entry.get("type", "rss"),
                enabled=entry.get("enabled", True),
                category=entry.get("category"),
            )
        )
        inserted += 1
    if inserted:
        await session.flush()
    return inserted