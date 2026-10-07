# Aetherix — Alembic migrations

This directory is bootstrapped by `alembic init`. Until then, the backend
calls `Base.metadata.create_all` on startup (Phase 1).

Once Phase 2 starts:

```bash
cd backend
alembic init -t async ../database/migrations
# edit alembic.ini + env.py to read from app.core.config
alembic revision --autogenerate -m "initial schema"
alembic upgrade head
```

## Tables covered (docs §29)

- sources
- categories
- articles (UNIQUE canonical_url)
- article_categories (M:N)
- bookmarks
- users
- devices
- processing_jobs