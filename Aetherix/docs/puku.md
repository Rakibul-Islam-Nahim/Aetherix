# Puku integration

Puku is the AI worker (docs §57). It lives on the VPS host and reaches the
backend through the `/mcp` endpoints.

## Agent files

- `puku/agents/tech_news_agent.md` — agent description
- `puku/skills/aetherix_mcp.md` — MCP skill Puku loads at runtime
- `puku/prompts/process_article.md` — per-article prompt

Edit the prompt to refine tone or add filtering rules. No backend code
changes required.

## Cron

The `setup-vps.sh` script writes:

```
*/15 * * * * /usr/local/bin/puku run \
  --config /opt/aetherix/puku \
  --agent TechNewsAgent \
  >> /var/log/aetherix-puku.log 2>&1
```

Inspect logs:

```bash
tail -f /var/log/aetherix-puku.log
```

## Failure handling (docs §41)

Puku should call `publish_article` per article, not batch. If the run
crashes halfway:

- Articles already published are durable.
- Articles not yet published stay `DISCOVERED` — the next cron tick
  re-pulls them via `get_new_articles`.
- Final `report_job_status` records what happened.