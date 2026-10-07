# Architecture

See `Aetherix_Documentations.md` (project root) for the canonical design.

## TL;DR

```
Internet
   │
   ▼
Cloudflare (news.cybersentinel.top, TLS, edge)
   │
   ▼
Cloudflare Tunnel
   │
   ▼
VPS
├── Puku CLI  (host)   ── TechNewsAgent
└── Docker Compose
   ├── FastAPI (REST + MCP, port 8000)
   └── PostgreSQL 16
```

## Three independent layers (docs §57)

| Layer | Job | Replaceable? |
| --- | --- | --- |
| Puku CLI | Intelligence (discover, summarize, score) | Yes |
| FastAPI + Postgres | Coordination + storage | Yes |
| Flutter | Presentation | Yes |

Replacing any one of these layers keeps the others working unchanged.

## Why this shape

- One VPS is enough for a personal app (docs §53).
- Puku stays on the host so it has its CLI environment (docs §26).
- PostgreSQL is never reachable from the internet — only via the backend on
  the Docker network (docs §37).
- Cron triggers Puku every 15 minutes — no Redis/Celery/Kubernetes (docs §27).