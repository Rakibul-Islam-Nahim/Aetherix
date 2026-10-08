"""One-off DB migration: rewrite every article's categories through the
allowlist normalizer.

Run with::

    python -m app.services.tag_normalize_db

This walks every Article, looks at its current ``ArticleCategory`` rows,
collapses them to the 4-tag allowlist, deduplicates, and rewrites the
secondary table. Articles end up with 1-4 normalized tags. Articles that
had no categories at all get a single ``Technology`` tag.
"""
from __future__ import annotations

import asyncio

from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload

from app.core.database import AsyncSessionLocal
from app.models.orm import Article, ArticleCategory, Category
from app.services.tag_normalize import normalize


async def _rewrite_one(session, article: Article) -> tuple[int, list[str]]:
    raw = [c.name for c in article.categories or []]
    new_tags = normalize(raw)
    await session.execute(
        delete(ArticleCategory).where(ArticleCategory.article_id == article.id)
    )
    for tag in new_tags:
        cat_stmt = select(Category).where(Category.name == tag)
        cat = (await session.execute(cat_stmt)).scalar_one_or_none()
        if cat is None:
            cat = Category(name=tag)
            session.add(cat)
            await session.flush()
        session.add(ArticleCategory(article_id=article.id, category_id=cat.id))
    return article.id, new_tags


async def _run() -> None:
    rewrites = 0
    async with AsyncSessionLocal() as session:
        stmt = select(Article).options(selectinload(Article.categories))
        rows = (await session.execute(stmt)).scalars().all()
        for article in rows:
            await _rewrite_one(session, article)
            rewrites += 1
        await session.commit()
    print(f"normalized {rewrites} articles")


if __name__ == "__main__":
    asyncio.run(_run())