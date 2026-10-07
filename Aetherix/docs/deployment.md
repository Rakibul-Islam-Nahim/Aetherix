# Deployment

Target: a fresh Ubuntu/Debian VPS. The `setup-vps.sh` script does
everything.

## One-shot

```bash
scp scripts/setup-vps.sh user@vps:~
ssh user@vps
bash setup-vps.sh
```

## What the script does

1. Installs Docker + Compose plugin.
2. Installs Puku CLI stub (replace with real Puku when available).
3. Installs FVM + the latest stable Flutter (for management).
4. Clones the repo into `/opt/aetherix`.
5. Creates `.env` from `.env.example` with random JWT/worker secrets.
6. Brings up Postgres + backend + cloudflared via `docker compose up -d`.
7. Writes a 15-minute cron entry for Puku.
8. Configures UFW (SSH + localhost-only backend).

## Manual steps after the script

Edit `/opt/aetherix/.env`:

- Set `CLOUDFLARE_TUNNEL_TOKEN` from Cloudflare Zero Trust.
- Set `DOMAIN=news.cybersentinel.top`.

Then:

```bash
cd /opt/aetherix
sudo docker compose up -d --build cloudflared
sudo docker compose logs -f backend
curl -s http://127.0.0.1:8000/api/v1/health
```

## Updates

```bash
cd /opt/aetherix
git pull
sudo docker compose up -d --build backend
sudo docker compose restart cloudflared
```

## Backups

Phase 8: schedule `pg_dump` daily to `/backups/` and rotate offsite.