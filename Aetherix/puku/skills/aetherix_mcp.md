# aetherix-mcp

A Puku **skill** that teaches the agent how to talk to the Aetherix backend.

Puku loads this skill at runtime so TechNewsAgent discovers the MCP tools
automatically. The skill description is short — the actual prompt lives in
`../prompts/process_article.md`.

## What this skill exports

Puku MCP tools (matches `backend/app/mcp/server.py`):

| Tool | Method | Path |
| --- | --- | --- |
| `get_sources` | GET | `/mcp/get_sources` |
| `get_new_articles` | GET | `/mcp/get_new_articles` |
| `publish_article` | POST | `/mcp/publish_article` |
| `mark_processed` | POST | `/mcp/mark_processed` |
| `report_job_status` | POST | `/mcp/report_job_status` |

## Auth

All MCP tools require the worker token:

```
Authorization: Bearer ${PUKU_WORKER_TOKEN}
```

The token is read from the host environment by Puku. It is **never** sent
to a Flutter user and is **never** stored in the database.

## When to call

- Start of every run: `get_sources`, `get_new_articles`
- For each article: `publish_article` (this single call dedupes + persists)
- End of run: `report_job_status`

If `publish_article` returns `created: false`, the article was already in
the database. That's fine — the updated fields still applied.

## Failure handling

- Network error → log + skip; cron retries on the next 15-minute tick.
- Auth 401 → stop the job; alert the owner.
- 5xx → exponential backoff (1s, 4s, 16s), then skip that article.