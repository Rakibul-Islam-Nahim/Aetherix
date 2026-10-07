"""FastAPI application entrypoint."""
from __future__ import annotations

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.internal import router as internal_router
from app.api.routes import router as api_router
from app.core.config import get_settings
from app.core.database import AsyncSessionLocal, Base, engine
from app.core.logging import configure_logging, get_logger
from app.mcp.server import router as mcp_router
from app.services import seed_service

configure_logging(get_settings().log_level)
logger = get_logger("aetherix.backend")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("aetherix_backend_starting")
    # Create tables on boot (Phase 1). Alembic takes over in Phase 2.
    # We tolerate DB-unreachable so that local smoke testing works
    # without postgres. In Docker, AETHERIX_SKIP_BOOTSTRAP=0 (default)
    # and DB is reachable, so tables get created.
    skip = os.environ.get("AETHERIX_SKIP_BOOTSTRAP") == "1"
    if not skip:
        try:
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            # First-boot seed: import default_sources.json if the
            # sources table is empty.
            try:
                async with AsyncSessionLocal() as s:
                    inserted = await seed_service.seed_default_sources(s)
                    await s.commit()
                if inserted:
                    logger.info("aetherix_seeded_sources", count=inserted)
            except Exception as exc:  # noqa: BLE001
                logger.warning("aetherix_seed_failed", error=str(exc))
            logger.info("aetherix_backend_ready_db_ok")
        except Exception as exc:  # noqa: BLE001
            logger.warning("aetherix_backend_ready_no_db", error=str(exc))
    else:
        logger.info("aetherix_backend_ready_bootstrap_skipped")
    yield
    logger.info("aetherix_backend_shutdown")


app = FastAPI(
    title="Aetherix Backend",
    version="0.1.0",
    description="Tech-news coordination + storage layer. See /docs for API.",
    lifespan=lifespan,
)

# CORS — Flutter Android + Windows native clients don't need CORS, but Flutter Web will.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(api_router)
app.include_router(mcp_router)
app.include_router(internal_router)


@app.get("/", include_in_schema=False)
async def root() -> dict[str, str]:
    return {
        "service": "aetherix-backend",
        "docs": "/docs",
        "health": "/api/v1/health",
    }