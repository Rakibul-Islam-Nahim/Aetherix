# Puku — Aetherix worker definitions

This directory holds the **declarative** parts of the AI worker. The actual
Puku CLI is installed on the VPS host (see `scripts/setup-vps.sh`).

```
puku/
├── agents/
│   └── tech_news_agent.md       # agent description (loaded by `puku run --agent`)
├── skills/
│   └── aetherix_mcp.md          # MCP contract Puku uses to call our backend
├── prompts/
│   └── process_article.md       # per-article instruction set
└── README.md                    # this file
```

## How Puku consumes this

```
/usr/local/bin/puku run \
  --config /opt/aetherix/puku \
  --agent TechNewsAgent
```

Puku reads the agent description and skill, then follows the per-article
prompt for every new article the backend hands it.

## Iteration workflow

1. Edit `prompts/process_article.md` to refine tone or add rules.
2. Run `puku run --agent TechNewsAgent --dry-run` on the VPS to inspect
   what Puku *would* output without persisting.
3. Once happy, drop `--dry-run`.

No backend code changes are required for prompt tweaks.