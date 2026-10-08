#!/usr/bin/env bash
# ============================================================
# Aetherix — redeploy with Flutter web UI baked into the backend.
#
# Run this on the host where the existing backend container is up.
# It rebuilds the backend image so /static is included, restarts the
# backend container, and verifies both the API and the UI respond.
# ============================================================

set -euo pipefail

INSTALL_DIR="${AETHERIX_INSTALL_DIR:-/opt/aetherix}"
BACKEND_CONTAINER="${BACKEND_CONTAINER:-aetherix-backend}"

step()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }
ok()    { printf "    \033[1;32m✓\033[0m %s\n" "$1"; }
warn()  { printf "    \033[1;33m!\033[0m %s\n" "$1"; }

[[ -d "${INSTALL_DIR}" ]] || { echo "Install dir not found: ${INSTALL_DIR}"; exit 1; }
cd "${INSTALL_DIR}"

step "Pull repo"
git pull --ff-only || warn "git pull failed; continuing"

step "Build Flutter web bundle"
if ! command -v fvm >/dev/null 2>&1; then
  warn "fvm not on PATH. Trying 'flutter' directly."
  FLUTTER="flutter"
else
  FLUTTER="fvm flutter"
fi

cd flutter/Aetherix_app
${FLUTTER} build web --release \
  --dart-define=AETHERIX_API_BASE_URL=https://news.cybersentinel.top/api/v1
cd "${INSTALL_DIR}"

step "Copy bundle into backend/static/"
rm -rf backend/static
mkdir -p backend/static
cp -r flutter/Aetherix_app/build/web/* backend/static/
ok "Copied $(ls backend/static | wc -l) files into backend/static/"

step "Rebuild + restart backend container"
sudo docker compose build backend
sudo docker compose up -d --no-deps backend
sleep 3
sudo docker compose ps backend

step "Verify"
printf "    %s\n" \
  "$(curl -fsS -o /dev/null -w 'GET /             %{http_code}  %{content_type}' http://127.0.0.1:8000/)" \
  "$(curl -fsS -o /dev/null -w 'GET /index.html   %{http_code}  %{content_type}' http://127.0.0.1:8000/index.html)" \
  "$(curl -fsS -o /dev/null -w 'GET /main.dart.js %{http_code}  %{content_type}' http://127.0.0.1:8000/main.dart.js)" \
  "$(curl -fsS -o /dev/null -w 'GET /api/v1/health %{http_code}  %{content_type}' http://127.0.0.1:8000/api/v1/health)"

ok "Done. Open https://news.cybersentinel.top/ in your browser."