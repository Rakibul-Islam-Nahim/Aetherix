# Aetherix

**Personal tech-news intelligence platform.**

Aetherix continuously discovers technology and cybersecurity news, runs it through the **Puku CLI** as the AI worker, stores structured summaries in a **FastAPI + PostgreSQL** backend, and presents them in a cross-platform **Flutter** application (Android + Windows).

> Public endpoint: `https://news.cybersentinel.top`
>
> See `docs/architecture.md` for the full architecture and `Aetherix_Documentations.md` (project root) for the design rationale.

---

## Architecture at a glance

```
Internet → Cloudflare → Tunnel → VPS
├── Puku CLI (host) ← TechNewsAgent
└── Docker Compose
   ├── FastAPI (REST + MCP)
   └── PostgreSQL
↑ Flutter (Android + Windows)
Cron (15-min) → Puku → Discover → Summarize → Backend → Flutter
```

**Three independent layers** (per docs §57):
- **Puku** = Intelligence (what's new, what's relevant, what does it mean)
- **Backend** = Coordination + storage (FastAPI ↔ PostgreSQL, REST + MCP)
- **Flutter** = Presentation (UI, bookmarks, search)

Replacing any one of these layers keeps the others working.

---

## Repo structure (per docs §50)

```
Aetherix/
├── README.md                       ← this file
├── docker-compose.yml              ← postgres + backend + cloudflared
├── .env.example                    ← copy to .env on VPS
├── .gitignore
│
├── backend/                       ← Python FastAPI service
│   ├── app/{api,models,schemas,services,repositories,mcp,core,main.py}
│   ├── tests/
│   └── Dockerfile + requirements.txt
│
├── flutter/Aetherix_app/          ← Flutter app (Android + Windows)
│
├── puku/                          ← Puku agent + skills + prompts
│   ├── agents/
│   ├── skills/
│   └── prompts/
│
├── database/
│   ├── migrations/                ← Alembic
│   └── seeds/
│
├── infrastructure/
│   ├── cloudflare/                ← tunnel setup notes
│   └── docker/
│
├── docs/                          ← architecture, api, puku, deployment, security
│
└── scripts/
    └── setup-vps.sh               ← one-shot VPS provisioning script
```

---

## Quick start (local dev)

### 1. Clone

```bash
git clone https://github.com/<you>/Aetherix.git
cd Aetherix
cp .env.example .env
# fill in real secrets before continuing
```

### 2. Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate     # Windows: .venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```

### 3. Flutter app

```bash
cd flutter/Aetherix_app
fvm use stable                # picks the latest stable Flutter
fvm flutter pub get
fvm flutter run               # or --platforms=android
```

---

## VPS deployment (production)

The `scripts/setup-vps.sh` script does the full provisioning in one shot:

```bash
scp scripts/setup-vps.sh user@vps:~
ssh user@vps
bash setup-vps.sh
```

What it does:
1. Installs Docker + Docker Compose plugin + nginx + cloudflared
2. Clones the repo into `/opt/aetherix`
3. Copies `.env.example` → `.env` (you edit secrets)
4. Generates `JWT_SECRET` and `PUKU_WORKER_TOKEN` if blank
5. Starts `postgres` + `backend` + `cloudflared` via `docker compose up -d`
6. Installs a cron entry that triggers Puku every 15 minutes
7. Prints the health URL and next steps

See `docs/deployment.md` for the full walkthrough.

---

## Development phases

This project is built in 10 phases. Current status tracked in `docs/` notes.

| Phase | What | Status |
|-------|------|--------|
| 0 | Architecture + docs | in progress |
| 1 | Backend foundation (FastAPI + Postgres) | scaffolded |
| 2 | News source system (RSS) | pending |
| 3 | Puku integration (MCP) | pending |
| 4 | AI processing pipeline | pending |
| 5 | Scheduler (cron) | pending |
| 6 | Flutter UI | scaffolded |
| 7 | VPS deployment | scaffolded |
| 8 | Security (JWT, rate limiting) | pending |
| 9 | Notifications | pending |
| 10 | Intelligence improvements | pending |

---

## Documentation

- `docs/architecture.md` — system design
- `docs/api.md` — REST + MCP endpoints
- `docs/database.md` — PostgreSQL schema
- `docs/puku.md` — Puku agent + MCP contract
- `docs/deployment.md` — VPS deployment walkthrough
- `docs/security.md` — auth, tokens, secrets
- `Aetherix_Documentations.md` — original design doc (single source of truth)

---

## License

Personal project. All rights reserved by the owner.