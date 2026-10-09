"""REST API v1 routes - surfaced to Flutter."""
from __future__ import annotations

from datetime import datetime, time, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import or_, select
from sqlalchemy.orm import selectinload

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
from app.services import tag_normalize
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

    If the matching User has been blocked by the admin (``is_active`` is
    False), refuse with 403. The client sees a permanent auth failure
    until the admin unblocks.
    """
    stmt = select(User).where(User.username == body.name)
    user = (await session.execute(stmt)).scalar_one_or_none()
    if user is not None and not user.is_active:
        # Blocked user. Reject with a stable 403 so the client can
        # distinguish from "no token yet".
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is blocked",
        )
    if user is None:
        user = User(username=body.name, is_active=True)
        session.add(user)
        await session.flush()
    # Persist the most recent Device row so the admin panel can show
    # "last seen" + device model. The original code path only created
    # users, never devices; we keep that for backward compat.
    try:
        from app.models.orm import Device
        device = Device(
            user_id=user.id,
            name=body.name,
            platform=body.platform,
            model=body.model,
            token_hash="pending",  # placeholder, real token is JWT, not stored
            last_seen_at=datetime.now(timezone.utc),
        )
        session.add(device)
    except Exception as exc:  # noqa: BLE001
        # Don't fail registration if Device persistence has an issue;
        # log and continue.
        from app.core.logging import get_logger
        get_logger("aetherix.auth").warning("device_persist_skipped", error=str(exc))
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
    tag: str | None = Query(default=None, max_length=50),
    date_from: str | None = Query(default=None, alias="from"),
    date_to: str | None = Query(default=None, alias="to"),
    _user: dict = Depends(require_user),
) -> list[ArticleSummary]:
    """List processed articles.

    Optional filters:
      - ``tag``          single primary tag from the Aetherix allowlist.
      - ``from``/``to``  inclusive YYYY-MM-DD range; applied to
                         ``published_at`` when present, falling back to
                         ``discovered_at``.
    """
    parsed_from = _parse_day(date_from, "from", end_of_day=False)
    parsed_to = _parse_day(date_to, "to", end_of_day=True)
    rows = await article_repo.list_recent_articles(
        session,
        limit=pagination.limit,
        offset=pagination.offset,
        date_from=parsed_from,
        date_to=parsed_to,
    )
    tag_norm = tag_normalize.map_one(tag) if tag else None
    out: list[ArticleSummary] = []
    for r in rows:
        primary = _primary_tag(r)
        if tag_norm is not None and primary != tag_norm:
            continue
        summary = ArticleSummary.model_validate(r)
        summary.tag = primary
        out.append(summary)
    return out


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
    detail = ArticleDetail.model_validate(article)
    detail.tag = _primary_tag(article)
    return detail


# ----- search -----
@router.get("/search", response_model=list[SearchOut])
async def search(
    q: str = Query(min_length=1, max_length=200),
    limit: int = Query(50, ge=1, le=200),
    session: DBSession = None,  # type: ignore[assignment]
    _user: dict = Depends(require_user),
) -> list[SearchOut]:
    """ILIKE search across title, summary, what_happened, why_it_matters,
    plus category.name and source.name."""
    like = f"%{q}%"
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
        .options(selectinload(Article.categories), selectinload(Article.source))
    )
    rows = (await session.execute(stmt)).scalars().all()
    out: list[SearchOut] = []
    for r in rows:
        s = SearchOut.model_validate(r)
        s.tag = _primary_tag(r)
        out.append(s)
    return out


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
    out: list[BookmarkOut] = []
    for row in rows:
        bookmark, title, url = row
        out.append(
            BookmarkOut.model_validate(
                {
                    "id": bookmark.id,
                    "user_id": bookmark.user_id,
                    "article_id": bookmark.article_id,
                    "created_at": bookmark.created_at,
                    "article_title": title,
                    "article_canonical_url": url,
                }
            )
        )
    return out


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


# --------- helpers --------
def _parse_day(raw: str | None, field: str, *, end_of_day: bool):
    """Parse ``YYYY-MM-DD`` into a tz-aware datetime UTC."""
    if not raw:
        return None
    try:
        d = datetime.strptime(raw, "%Y-%m-%d").date()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"{field} must be YYYY-MM-DD",
        ) from exc
    if end_of_day:
        return datetime.combine(d, time.max, tzinfo=timezone.utc)
    return datetime.combine(d, time.min, tzinfo=timezone.utc)


def _primary_tag(article: Article) -> str:
    cats = [c.name for c in (article.categories or [])]
    return tag_normalize.primary(cats) if cats else "Technology"