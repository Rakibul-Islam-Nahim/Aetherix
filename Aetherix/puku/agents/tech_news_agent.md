# TechNewsAgent

> The AI layer of Aetherix. Reads news discovered by the backend, analyzes,
> summarizes, categorizes, scores, and publishes back via MCP.

This directory is the agent definition consumed by Puku on the VPS host.
The matching skill (callable from prompts) lives in `../skills/`.

## Responsibility

```
Discover  → Understand → Filter → Summarize → Categorize → Score → Publish
```

Puku is **not** the backend. Puku is **not** the database. Puku is the
intelligent worker.

## Workflow

1. `GET /mcp/get_sources`  — list enabled RSS sources
2. `GET /mcp/get_new_articles`  — pull DISCOVERED articles
3. For each article:
   - Read the URL content
   - Filter relevance (drop celebrity/marketing noise)
   - Generate the structured summary fields
   - Assign category + importance score (1–10)
4. `POST /mcp/publish_article` — one call per processed article
5. `POST /mcp/report_job_status` — once at the end

## Tool contract

Puku authenticates with the **worker token** in `Authorization: Bearer`:

```
Authorization: Bearer ${PUKU_WORKER_TOKEN}
```

Puku does **not** hold a user JWT. Puku does **not** read PostgreSQL directly.

## Running on the VPS

The bootstrap script installs a 15-minute cron entry:

```bash
*/15 * * * * /usr/local/bin/puku run \
  --config /opt/aetherix/puku \
  --agent TechNewsAgent \
  >> /var/log/aetherix-puku.log 2>&1
```

## Prompt file

The instructions Puku should follow per article live in
`prompts/process_article.md`. Adjust the rules there to refine behaviour
without touching code.