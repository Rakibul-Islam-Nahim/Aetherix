"""REST API v1 routes — surfaced to Flutter."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.api.deps import DBSession, PaginationDep
from app.core.security import require_user
from app.models.orm import Article, Bookmark, Category, ProcessingStatus, Source
from app.repositories import article_repo
from app.schemas.dtos import (
    ArticleDetail,
    ArticleSummary,
    BookmarkIn,
    BookmarkOut,
    CategoryOut,
    SourceOut,
)

router = APIRouter(prefix="/api/v1", tags=["public"])


@router.get("/health")
async def health(session: DBSession) -> dict:
    """Liveness + DB ping."""
    db_ok = False
    try:
        await session.execute(select(1))
        db_ok = True
    except Exception:
        db_ok = False
    return {"status": "ok" if db_ok else "degraded", "db": db_ok, "version": "0.1.0"}


# ----- news -----
@router.get("/news", response_model=list[ArticleSummary])
async def list_news(
    session: DBSession,
    pagination: PaginationDep,
    _user: dict = __import__("fastapi").Depends(require_user),
) -> list[ArticleSummary]:
    rows = await article_repo.list_recent_articles(
        session, limit=pagination.limit, offset=pagination.offset
    )
    return [ArticleSummary.model_validate(r) for r in rows]


@router.get("/news/{article_id}", response_model=ArticleDetail)
async def get_article(
    article_id: int,
    session: DBSession,
    _user: dict = __import__("fastapi").Depends(require_user),
) -> ArticleDetail:
    article = await article_repo.get_article_with_relations(session, article_id)
    if article is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
    return ArticleDetail.model_validate(article)


# ----- categories / sources -----
@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(
    session: DBSession,
    _user: dict = __import__("fastapi").Depends(require_user),
) -> list[CategoryOut]:
    rows = (await session.execute(select(Category).order_by(Category.name))).scalars().all()
    return [CategoryOut.model_validate(r) for r in rows]


@router.get("/sources", response_model=list[SourceOut])
async def list_sources(
    session: DBSession,
    _user: dict = __import__("fastapi").Depends(require_user),
) -> list[SourceOut]:
    rows = (
        await session.execute(select(Source).order_by(Source.name))
    ).scalars().all()
    return [SourceOut.model_validate(r) for r in rows]


# ----- bookmarks -----
@router.post(
    "/bookmarks",
    response_model=BookmarkOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_bookmark(
    body: BookmarkIn,
    session: DBSession,
    _user: dict = __import__("fastapi").Depends(require_user),
) -> BookmarkOut:
    article = await session.get(Article, body.article_id)
    if article is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Article not found")
    if article.processing_status != ProcessingStatus.PROCESSED.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Article not yet processed",
        )
    bookmark = await article_repo.add_bookmark(session, body.article_id)
    await session.commit()
    return BookmarkOut.model_validate(bookmark)


@router.get("/bookmarks", response_model=list[BookmarkOut])
async def list_user_bookmarks(
    session: DBSession,
    _user: dict = __import__("fastapi").Depends(require_user),
) -> list[BookmarkOut]:
    rows = await article_repo.list_bookmarks(session)
    return [BookmarkOut.model_validate(r) for r in rows]