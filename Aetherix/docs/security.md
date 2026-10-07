# Security

Per docs §34–§38.

## Three identities

| Identity | How it proves itself | Where it's stored |
| --- | --- | --- |
| Flutter user / device | JWT (HS256) | device secure storage |
| Puku worker | static `PUKU_WORKER_TOKEN` (constant-time compare) | host env / .env |
| Cloudflare Tunnel | `CLOUDFLARE_TUNNEL_TOKEN` | host env / .env |

**Never** reuse one token for another role. The Puku token is *not* a user
JWT, and a user's JWT is *not* a worker credential.

## Network (docs §37)

- PostgreSQL has no public port — backend talks to it on the docker bridge.
- Backend listens on `127.0.0.1:8000` on the host. Only the cloudflared
  container can reach it.
- UFW allows SSH + (local-only) 8000. Nothing else.

## Never commit

- `.env`
- JWT secrets
- Worker tokens
- Cloudflare credentials
- `cloudflared-*.pem`

The `.gitignore` already excludes these.

## Rate limiting (Phase 8)

Use a single token-bucket middleware (Redis-free) before exposing more
endpoints. Cloudflare provides edge-level limits as a baseline.

## Input validation

All Pydantic schemas enforce types at the boundary. Puku payloads
validate `importance_score` between 1 and 10. URLs are validated as
`HttpUrl`.