# API

Base path: `/api/v1` for Flutter, `/mcp` for Puku.

## Auth

- Flutter clients: `Authorization: Bearer <jwt>` issued by device register.
- Puku worker:    `Authorization: Bearer ${PUKU_WORKER_TOKEN}` (constant).

## Public (Flutter) — docs §22

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/v1/health` | liveness + DB ping |
| GET | `/api/v1/news` | list processed articles |
| GET | `/api/v1/news/{id}` | full article + categories + source |
| GET | `/api/v1/categories` | all categories |
| GET | `/api/v1/sources` | all sources |
| GET | `/api/v1/search?q=…` | search title/summary/category/source |
| POST | `/api/v1/bookmarks` | bookmark an article |
| GET | `/api/v1/bookmarks` | list user's bookmarks |
| POST | `/api/v1/auth/register-device` | trade device name for JWT |

## MCP (Puku) — docs §19

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/mcp/get_sources` | list enabled sources |
| GET | `/mcp/get_new_articles` | list DISCOVERED articles |
| POST | `/mcp/publish_article` | upsert one processed article |
| POST | `/mcp/mark_processed` | mark an article processed |
| POST | `/mcp/report_job_status` | record a processing_jobs row |

## Pydantic schemas

Schemas live in `backend/app/schemas/dtos.py`. The Flutter Dart models are
in `flutter/Aetherix_app/lib/models/`. Keep them in sync.