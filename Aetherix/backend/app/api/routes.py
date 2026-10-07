"""REST API v1 routes — surfaced to Flutter."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import or_, select

from app.api.deps import DBSession, PaginationDep
from app.core.config import get_settings
from app.core.security import create_access_token, require_user
from app.models.orm import (
    Article,
    ArticleCategory,
    Bookmark,
    Category,
    ProcessingStatus,
    Source,
    User,
)
from app.repositories import article_repo
from app.schemas.dtos import (
    ArticleDetail,
    ArticleSummary,
    BookmarkIn,
    BookmarkOut,
    CategoryOut,
    DeviceRegisterIn,
    DeviceRegisterOut,
    SearchOut,
    SourceOut,
)

router = APIRouter(prefix="/api/v1", tags=["public"])


def _user_id_from_claims(claims: dict) -> int:
    sub = claims.get("sub")
    if sub is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing sub",
        )
    try:
        return int(sub)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token sub is not an integer",
        ) from exc


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


# ----- auth: register a Flutter device, mint a token -----
@router.post(
    "/auth/register-device",
    response_model=DeviceRegisterOut,
    status_code=status.HTTP_201_CREATED,
)
async def register_device(
    body: DeviceRegisterIn,
    session: DBSession,
) -> DeviceRegisterOut:
    """Single-user personal app: one Device = one User.

    If the username (device name) is new, we create a User. Otherwise we
    return the existing user. The Flutter client then stores the JWT and
    re-uses it for every subsequent request.
    """
    stmt = select(User).where(User.username == body.name)
    user = (await session.execute(stmt)).scalar_one_or_none()
    if user is None:
        user = User(username=body.name, is_active=True)
        session.add(user)
        await session.flush()
    settings = get_settings()
    token = create_access_token(subject=str(user.id))
    await session.commit()
    return DeviceRegisterOut(
        user_id=user.id,
        access_token=token,
        expires_in_minutes=settings.jwt_expires_minutes,
    )


# ----- news -----
@router.get("/news", response_model=list[ArticleSummary])
async def list_news(
    session: DBSession,
    pagination: PaginationDep,
    _user: dict = Depends(require_user),
) -> list[ArticleSummary]:
    rows = await article_repo.list_recent_articles(
        session, limit=pagination.limit, offset=pagination.offset
    )
    return [ArticleSummary.model_validate(r) for r in rows]


@router.get("/news/{article_id}", response_model=ArticleDetail)
async def get_article(
    article_id: int,
    session: DBSession,
    _user: dict = Depends(require_user),
) -> ArticleDetail:
    article = await article_repo.get_article_with_relations(session, article_id)
    if article is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Article not found"
        )
    return ArticleDetail.model_validate(article)


# ----- search -----
@router.get("/search", response_model=list[SearchOut])
async def search(
    q: str = Query(min_length=1, max_length=200),
    limit: int = Query(50, ge=1, le=200),
    session: DBSession = DBSession.__class__,  # type: ignore[assignment]
    _user: dict = Depends(require_user),
) -> list[SearchOut]:
    """ILIKE search across title, summary, what_happened, why_it_matters,
    plus category.name and source.name."""
    like = f"%{q}%"
    cat_ids_sub = select(ArticleCategory.category_id)
    stmt = (
        select(Article)
        .outerjoin(ArticleCategory, ArticleCategory.article_id == Article.id)
        .outerjoin(Category, Category.id == ArticleCategory.category_id)
        .outerjoin(Source, Source.id == Article.source_id)
        .where(
            Article.processing_status == ProcessingStatus.PROCESSED.value,
            or_(
                Article.title.ilike(like),
                Article.summary.ilike(like),
                Article.what_happened.ilike(like),
                Article.why_it_matters.ilike(like),
                Category.name.ilike(like),
                Source.name.ilike(like),
            ),
        )
        .order_by(Article.published_at.desc().nulls_last())
        .limit(limit)
        .distinct()
    )
    del cat_ids_sub  # silence "unused" — kept above for readability
    rows = (await session.execute(stmt)).scalars().all()
    return [SearchOut.model_validate(r) for r in rows]


# ----- categories / sources -----
@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(
    session: DBSession,
    _user: dict = Depends(require_user),
) -> list[CategoryOut]:
    rows = (await session.execute(select(Category).order_by(Category.name))).scalars().all()
    return [CategoryOut.model_validate(r) for r in rows]


@router.get("/sources", response_model=list[SourceOut])
async def list_sources(
    session: DBSession,
    _user: dict = Depends(require_user),
) -> list[SourceOut]:
    rows = (
        await session.execute(select(Source).order_by(Source.name))
    ).scalars().all()
    return [SourceOut.model_validate(r) for r in rows]


# ----- bookmarks (user-scoped) -----
@router.post(
    "/bookmarks",
    response_model=BookmarkOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_bookmark(
    body: BookmarkIn,
    session: DBSession,
    claims: dict = Depends(require_user),
) -> BookmarkOut:
    user_id = _user_id_from_claims(claims)
    article = await session.get(Article, body.article_id)
    if article is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Article not found"
        )
    if article.processing_status != ProcessingStatus.PROCESSED.value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Article not yet processed",
        )
    bookmark = await article_repo.add_bookmark(
        session, user_id=user_id, article_id=body.article_id
    )
    await session.commit()
    return BookmarkOut.model_validate(bookmark)


@router.get("/bookmarks", response_model=list[BookmarkOut])
async def list_user_bookmarks(
    session: DBSession,
    claims: dict = Depends(require_user),
) -> list[BookmarkOut]:
    user_id = _user_id_from_claims(claims)
    rows = await article_repo.list_bookmarks_for_user(session, user_id)
    return [BookmarkOut.model_validate(r) for r in rows]


@router.delete("/bookmarks/{article_id}")
async def delete_bookmark(
    article_id: int,
    session: DBSession,
    claims: dict = Depends(require_user),
) -> Response:
    user_id = _user_id_from_claims(claims)
    deleted = await article_repo.delete_bookmark(
        session, user_id=user_id, article_id=article_id
    )
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bookmark not found",
        )
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)