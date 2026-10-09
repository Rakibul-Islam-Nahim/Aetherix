"""Admin panel endpoints.

Separate from `routes.py` so the user-facing API surface stays small.
All routes here require either an admin password (login) or the short-
lived admin JWT minted by login.

The admin password is read from ``ADMIN_PASSWORD`` in ``Settings``. In
production this must be set; the default in `config.py` is the dev
fallback the user picked.
"""
from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session, selectinload

from app.core.config import get_settings
from app.core.database import get_session
from app.core.logging import get_logger
from app.core.security import bearer_scheme
from app.models.orm import Device, User
from app.schemas.dtos import (
    AdminLoginIn,
    AdminLoginOut,
    DeviceAdminOut,
)

router = APIRouter(prefix="/admin", tags=["admin"])
logger = get_logger("aetherix.admin")

# Admin JWT is separate from the user JWT so a stolen user token cannot
# reach admin endpoints even if both share the same secret.
_ADMIN_JWT_TYPE = "admin"
_ADMIN_TOKEN_TTL_MIN = 60  # short-lived on purpose


def _mint_admin_jwt() -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": "admin",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=_ADMIN_TOKEN_TTL_MIN)).timestamp()),
        "type": _ADMIN_JWT_TYPE,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


async def require_admin(
    creds=Depends(bearer_scheme),
) -> dict:
    """Dependency: rejects anything but a fresh admin JWT.

    Uses a constant-time check pattern (re-decode + verify type) so
    failing branches don't leak the secret length.
    """
    if creds is None or not creds.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing admin token",
        )
    settings = get_settings()
    try:
        claims = jwt.decode(
            creds.credentials,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid admin token: {exc.__class__.__name__}",
        ) from exc
    if claims.get("type") != _ADMIN_JWT_TYPE:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not an admin token",
        )
    return claims


@router.post("/login", response_model=AdminLoginOut)
async def admin_login(body: AdminLoginIn) -> AdminLoginOut:
    """Constant-time password check + admin JWT.

    The password is verified with ``secrets.compare_digest`` to avoid
    timing leaks. Failure path returns the same generic 401 either way.
    """
    settings = get_settings()
    expected = settings.admin_password.encode("utf-8")
    got = body.password.encode("utf-8")
    if not secrets.compare_digest(expected, got):
        logger.warning("admin_login_failed")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin password",
        )
    return AdminLoginOut(
        access_token=_mint_admin_jwt(),
        expires_in_minutes=_ADMIN_TOKEN_TTL_MIN,
    )


@router.get("/devices", response_model=list[DeviceAdminOut])
async def list_devices(
    session: AsyncSession = Depends(get_session),
    _admin: dict = Depends(require_admin),
) -> list[DeviceAdminOut]:
    """Every device row joined to its user, newest first."""
    stmt = (
        select(Device, User)
        .join(User, Device.user_id == User.id)
        .order_by(Device.created_at.desc())
    )
    rows = (await session.execute(stmt)).all()
    return [
        DeviceAdminOut(
            id=d.id,
            name=d.name,
            platform=d.platform,
            model=d.model,
            user_id=u.id,
            username=u.username,
            user_blocked=not u.is_active,
            last_seen_at=d.last_seen_at,
            created_at=d.created_at,
        )
        for d, u in rows
    ]


@router.post("/devices/{device_id}/block", response_model=DeviceAdminOut)
async def block_device(
    device_id: int,
    session: AsyncSession = Depends(get_session),
    _admin: dict = Depends(require_admin),
) -> DeviceAdminOut:
    """Block the user behind this device.

    Blocking is a user-level operation: every Device belonging to that
    User becomes unable to log in, because ``register_device`` rejects
    users with ``is_active=False``.
    """
    stmt = select(Device).where(Device.id == device_id)
    device = (await session.execute(stmt)).scalar_one_or_none()
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Device not found"
        )
    user = await session.get(User, device.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    user.is_active = False
    await session.commit()
    logger.info("device_blocked", device_id=device_id, user_id=user.id)
    return DeviceAdminOut(
        id=device.id,
        name=device.name,
        platform=device.platform,
        model=device.model,
        user_id=user.id,
        username=user.username,
        user_blocked=True,
        last_seen_at=device.last_seen_at,
        created_at=device.created_at,
    )


@router.post("/devices/{device_id}/unblock", response_model=DeviceAdminOut)
async def unblock_device(
    device_id: int,
    session: AsyncSession = Depends(get_session),
    _admin: dict = Depends(require_admin),
) -> DeviceAdminOut:
    stmt = select(Device).where(Device.id == device_id)
    device = (await session.execute(stmt)).scalar_one_or_none()
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Device not found"
        )
    user = await session.get(User, device.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    user.is_active = True
    await session.commit()
    logger.info("device_unblocked", device_id=device_id, user_id=user.id)
    return DeviceAdminOut(
        id=device.id,
        name=device.name,
        platform=device.platform,
        model=device.model,
        user_id=user.id,
        username=user.username,
        user_blocked=False,
        last_seen_at=device.last_seen_at,
        created_at=device.created_at,
    )


@router.delete(
    "/devices/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
)
async def delete_device(
    device_id: int,
    session: AsyncSession = Depends(get_session),
    _admin: dict = Depends(require_admin),
):
    """Remove a Device row from the database.

    We intentionally do **not** delete the User. The User's bookmarks,
    history, and preferences are preserved; the next time this device
    calls ``/auth/register-device`` it gets a fresh Device row tied to
    the same User. To the client it's a transparent re-registration.
    """
    stmt = select(Device).where(Device.id == device_id)
    device = (await session.execute(stmt)).scalar_one_or_none()
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Device not found"
        )
    await session.delete(device)
    await session.commit()
    logger.info("device_deleted", device_id=device_id)


@router.post("/cleanup")
async def trigger_cleanup(
    session: AsyncSession = Depends(get_session),
    _admin: dict = Depends(require_admin),
) -> dict:
    """Run the monthly retention job on demand.

    Deletes every article with ``published_at`` before the 1st of
    the current month, except for articles that are still bookmarked
    by at least one user. Returns a small report (cutoff, eligible
    count, deleted count).
    """
    from app.services.cleanup_service import cleanup_old_articles

    report = await cleanup_old_articles(session)
    logger.info("admin_cleanup", **report)
    return report
