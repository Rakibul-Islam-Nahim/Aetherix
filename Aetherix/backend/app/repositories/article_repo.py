"""Read/write helpers for Article/Sources/Bookmarks."""
from __future__ import annotations

from datetime import datetime
from typing import Sequence

from sqlalchemy import and_, delete, func, insert, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.orm import (
    Article,
    ArticleCategory,
    Bookmark,
    Category,
    ProcessingStatus,
    Source,
)


# -------- sources --------
async def list_enabled_sources(session: AsyncSession) -> Sequence[Source]:
    stmt = select(Source).where(Source.enabled.is_(True)).order_by(Source.name)
    return (await session.execute(stmt)).scalars().all()


async def get_source_by_name(session: AsyncSession, name: str) -> Source | None:
    stmt = select(Source).where(Source.name == name)
    return (await session.execute(stmt)).scalar_one_or_none()


async def touch_source(session: AsyncSession, source: Source) -> None:
    source.last_checked_at = datetime.utcnow()
    session.add(source)
    await session.flush()


# -------- categories --------
async def get_or_create_category(session: AsyncSession, name: str) -> Category:
    stmt = select(Category).where(Category.name == name)
    cat = (await session.execute(stmt)).scalar_one_or_none()
    if cat is None:
        cat = Category(name=name)
        session.add(cat)
        await session.flush()
    return cat


# -------- articles --------
async def find_by_canonical(session: AsyncSession, canonical_url: str) -> Article | None:
    stmt = select(Article).where(Article.canonical_url == canonical_url)
    return (await session.execute(stmt)).scalar_one_or_none()


async def list_recent_articles(
    session: AsyncSession,
    *,
    limit: int = 50,
    offset: int = 0,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
) -> Sequence[Article]:
    """Return processed articles.

    When ``date_from`` / ``date_to`` are provided, the filter is applied to
    ``published_at`` if set, else to ``discovered_at`` (the canonical
    ingestion timestamp). Either bound may be None for open-ended ranges.
    """
    conditions = [
        Article.processing_status == ProcessingStatus.PROCESSED.value,
    ]
    if date_from is not None or date_to is not None:
        bounds = []
        if date_from is not None:
            bounds.append(
                func.coalesce(Article.published_at, Article.discovered_at)
                >= date_from
            )
        if date_to is not None:
            bounds.append(
                func.coalesce(Article.published_at, Article.discovered_at) <= date_to
            )
        conditions.append(and_(*bounds))

    stmt = (
        select(Article)
        .where(*conditions)
        .order_by(
            Article.published_at.desc().nulls_last(),
            Article.discovered_at.desc(),
        )
        .limit(limit)
        .offset(offset)
        .options(
            selectinload(Article.source),
            selectinload(Article.categories),
        )
    )
    return (await session.execute(stmt)).scalars().all()


async def get_article_with_relations(
    session: AsyncSession, article_id: int
) -> Article | None:
    stmt = (
        select(Article)
        .where(Article.id == article_id)
        .options(
            selectinload(Article.categories),
            selectinload(Article.source),
        )
    )
    return (await session.execute(stmt)).scalar_one_or_none()


async def upsert_processed_article(
    session: AsyncSession,
    *,
    canonical_url: str,
    title: str,
    source: Source,
    summary: str | None,
    what_happened: str | None,
    why_it_matters: str | None,
    importance_score: float | None,
    content_hash: str | None,
    categories: list[str],
    author: str | None,
    published_at: datetime | None,
) -> tuple[Article, bool]:
    """Insert if new, update if existing. Returns (article, created)."""
    article = await find_by_canonical(session, canonical_url)
    created = False
    if article is None:
        article = Article(
            canonical_url=canonical_url,
            url=canonical_url,
            title=title,
            source_id=source.id,
            author=author,
            published_at=published_at,
            processing_status=ProcessingStatus.PROCESSED.value,
        )
        session.add(article)
        created = True

    article.title = title
    article.summary = summary
    article.what_happened = what_happened
    article.why_it_matters = why_it_matters
    article.importance_score = importance_score
    article.content_hash = content_hash
    article.author = author or article.author
    article.published_at = published_at or article.published_at
    article.processing_status = ProcessingStatus.PROCESSED.value

    # categories - rewrite the secondary table directly. Assigning to
    # `article.categories` in SQLAlchemy 2.0 async triggers implicit
    # lazy-load I/O that fires outside the greenlet.
    resolved: list[Category] = []
    for name in categories:
        cat = await get_or_create_category(session, name)
        resolved.append(cat)

    await session.execute(
        delete(ArticleCategory).where(ArticleCategory.article_id == article.id)
    )
    for cat in resolved:
        await session.execute(
            insert(ArticleCategory).values(
                article_id=article.id, category_id=cat.id
            )
        )

    await session.flush()
    return article, created


async def mark_processed(session: AsyncSession, canonical_url: str) -> None:
    article = await find_by_canonical(session, canonical_url)
    if article:
        article.processing_status = ProcessingStatus.PROCESSED.value
        await session.flush()


# -------- bookmarks --------
async def add_bookmark(
    session: AsyncSession, *, user_id: int, article_id: int
) -> Bookmark:
    # idempotent - if (user, article) already exists, return the existing row
    stmt = select(Bookmark).where(
        Bookmark.user_id == user_id, Bookmark.article_id == article_id
    )
    existing = (await session.execute(stmt)).scalar_one_or_none()
    if existing is not None:
        return existing
    bookmark = Bookmark(user_id=user_id, article_id=article_id)
    session.add(bookmark)
    await session.flush()
    return bookmark


async def list_bookmarks_for_user(
    session: AsyncSession, user_id: int
) -> Sequence:
    """Return rows of (bookmark, article_title, article_canonical_url)
    for the given user, newest first.

    We pull title + url in the same query (left join) so the client
    can render bookmark rows without a follow-up fetch per item.
    Articles deleted by the retention job cascade their bookmarks
    away, so a missing article is normally impossible — but the
    outer join is still defensive.
    """
    stmt = (
        select(Bookmark, Article.title, Article.canonical_url)
        .join(Article, Article.id == Bookmark.article_id, isouter=True)
        .where(Bookmark.user_id == user_id)
        .order_by(Bookmark.created_at.desc())
    )
    return (await session.execute(stmt)).all()


async def delete_bookmark(
    session: AsyncSession, *, user_id: int, article_id: int
) -> bool:
    stmt = select(Bookmark).where(
        Bookmark.user_id == user_id, Bookmark.article_id == article_id
    )
    bookmark = (await session.execute(stmt)).scalar_one_or_none()
    if bookmark is None:
        return False
    await session.delete(bookmark)
    await session.flush()
    return True