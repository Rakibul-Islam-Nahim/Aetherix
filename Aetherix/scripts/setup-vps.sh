#!/usr/bin/env bash
# ============================================================
# Aetherix — one-shot VPS provisioning script
# Run as a non-root sudo user on a fresh Ubuntu/Debian VPS.
#
# What it does:
#   1. Installs Docker, Compose plugin, nginx (optional), git, curl
#   2. Installs Puku CLI on the host
#   3. Installs FVM + the latest stable Flutter (for management)
#   4. Clones the Aetherix repo into /opt/aetherix
#   5. Creates .env from .env.example with generated secrets
#   6. Brings up postgres + backend + cloudflared via docker compose
#   7. Installs the 15-minute cron job for Puku
#   8. Prints health URL + next steps
#
# Re-running is safe: it skips steps that are already done.
# ============================================================

set -euo pipefail

# ---------- config ----------
REPO_URL="${AETHERIX_REPO_URL:-https://github.com/<owner>/Aetherix.git}"
REPO_BRANCH="${AETHERIX_REPO_BRANCH:-main}"
INSTALL_DIR="${AETHERIX_INSTALL_DIR:-/opt/aetherix}"
PUKU_BIN_DIR="${PUKU_BIN_DIR:-/usr/local/bin}"
SCHEDULER_CRON="${SCHEDULER_CRON:-*/15 * * * *}"

# ---------- colors ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

step()  { printf "\n${BLUE}${BOLD}==>${NC} ${BOLD}%s${NC}\n" "$1"; }
ok()    { printf "    ${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "    ${YELLOW}!${NC} %s\n" "$1"; }
fail()  { printf "    ${RED}✗${NC} %s\n" "$1"; exit 1; }

require_root() {
  if [[ "$EUID" -eq 0 ]]; then
    fail "Do NOT run as root. Use a sudo user: bash setup-vps.sh"
  fi
  if ! sudo -n true 2>/dev/null; then
    fail "User has no passwordless sudo. Run: sudo apt update && sudo apt install -y sudo"
  fi
}

detect_os() {
  step "Detecting OS"
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_FAMILY="${ID:-ubuntu}"
    OS_VERSION="${VERSION_CODENAME:-}"
    ok "Detected ${PRETTY_NAME}"
  else
    fail "Cannot detect OS. This script targets Ubuntu/Debian."
  fi
}

# ---------- 1. apt packages ----------
install_packages() {
  step "Installing system packages"
  sudo apt update -y
  sudo apt install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      git \
      gnupg \
      jq \
      lsb-release \
      python3 \
      python3-pip \
      python3-venv \
      unzip \
      ufw \
      wget
  ok "System packages ready"
}

install_docker() {
  step "Installing Docker (if missing)"
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed: $(docker --version)"
  else
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    ok "Docker installed. (Log out and back in if 'docker' command fails.)"
  fi

  if docker compose version >/dev/null 2>&1; then
    ok "Compose plugin already present"
  else
    sudo apt install -y docker-compose-plugin
    ok "Compose plugin installed"
  fi
}

# ---------- 2. Puku CLI on the host ----------
install_puku() {
  step "Installing Puku CLI on the host (per docs §26 — Puku stays outside Docker)"
  if command -v puku >/dev/null 2>&1; then
    ok "Puku already installed: $(puku --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi
  # Placeholder install — replace with the real distribution source.
  warn "No official Puku install script known to this bootstrap yet."
  warn "Falling back to a stub in /usr/local/bin/puku so the cron job is valid."
  warn "Replace this block with: curl -fsSL https://puku.dev/install.sh | bash"
  sudo tee "${PUKU_BIN_DIR}/puku" > /dev/null <<'STUB'
#!/usr/bin/env bash
# Minimal Puku stub for Aetherix bootstrap.
# Replace once the real Puku CLI is installed on the host.
echo "[puku-stub $(date -Is)] would run TechNewsAgent now"
echo "[puku-stub] config: ${PUKU_CONFIG:-$HOME/.puku/config.json}"
exit 0
STUB
  sudo chmod +x "${PUKU_BIN_DIR}/puku"
  ok "Stub Puku installed at ${PUKU_BIN_DIR}/puku"
}

# ---------- 3. FVM + latest stable Flutter ----------
install_fvm_flutter() {
  step "Installing FVM + latest stable Flutter"
  if command -v fvm >/dev/null 2>&1; then
    ok "FVM already installed"
  else
    dart_pub_global="https://pub.dev"
    # FVM ships as a Dart pub global package
    if command -v dart >/dev/null 2>&1; then
      dart pub global activate fvm
      export PATH="$PATH:$HOME/.pub-cache/bin"
      ok "FVM installed via dart pub global"
    else
      warn "dart CLI not on PATH; installing Flutter SDK first to get dart"
      FLUTTER_TMP="$HOME/flutter-sdk-bootstrap"
      [[ -d "$FLUTTER_TMP" ]] || {
        git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_TMP"
        "$FLUTTER_TMP/bin/flutter" --no-version-check 1>/dev/null || true
      }
      export PATH="$PATH:$FLUTTER_TMP/bin"
      "$FLUTTER_TMP/bin/flutter" --disable-analytics >/dev/null 2>&1 || true
      "$FLUTTER_TMP/bin/dart" pub global activate fvm
      export PATH="$PATH:$HOME/.pub-cache/bin"
      ok "FVM installed via bootstrap Flutter"
    fi
    grep -qxF 'export PATH="$PATH:$HOME/.pub-cache/bin"' "$HOME/.bashrc" \
      || echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> "$HOME/.bashrc"
  fi

  export PATH="$PATH:$HOME/.pub-cache/bin"
  LATEST_STABLE="$(fvm releases 2>/dev/null | awk '/stable/ {print $1; exit}')"
  if [[ -z "${LATEST_STABLE:-}" ]]; then
    LATEST_STABLE="stable"
  fi
  fvm install "$LATEST_STABLE"
  fvm global "$LATEST_STABLE"
  ok "Flutter ${LATEST_STABLE} pinned via FVM"
}

# ---------- 4. clone repo ----------
clone_repo() {
  step "Cloning Aetherix repo → ${INSTALL_DIR}"
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    ok "Repo already present, pulling latest"
    (cd "${INSTALL_DIR}" && git pull --ff-only || warn "git pull failed; continuing")
  else
    sudo mkdir -p "${INSTALL_DIR}"
    sudo chown -R "$USER":"$USER" "${INSTALL_DIR}"
    git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
    ok "Cloned ${REPO_URL} (${REPO_BRANCH})"
  fi
}

# ---------- 5. .env ----------
ensure_env() {
  step "Creating .env from .env.example"
  cd "${INSTALL_DIR}"
  if [[ -f .env ]]; then
    ok ".env already exists — leaving untouched"
  else
    cp .env.example .env
    # generate secrets if placeholder
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')|" .env
    sed -i "s|^PUKU_WORKER_TOKEN=.*|PUKU_WORKER_TOKEN=$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')|" .env
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')|" .env
    ok "Generated JWT_SECRET, PUKU_WORKER_TOKEN, POSTGRES_PASSWORD"
    warn "Edit .env now to set CLOUDFLARE_TUNNEL_TOKEN and DOMAIN."
  fi
}

# ---------- 6. docker compose up ----------
bring_up_containers() {
  step "Bringing up Docker Compose (postgres + backend + cloudflared)"
  cd "${INSTALL_DIR}"

  if ! grep -q '^CLOUDFLARE_TUNNEL_TOKEN=.\+$' .env 2>/dev/null; then
    warn "CLOUDFLARE_TUNNEL_TOKEN is empty — cloudflared container will fail to start."
    warn "Edit .env, then re-run this script. (postgres + backend will still come up.)"
  fi

  sudo docker compose pull --ignore-pull-failures || true
  sudo docker compose up -d --build
  ok "Containers started"
  sudo docker compose ps
}

# ---------- 7. cron entry ----------
install_cron() {
  step "Installing 15-minute Puku cron entry"
  CRON_LINE="${SCHEDULER_CRON} /usr/local/bin/puku run --config /opt/aetherix/puku --agent TechNewsAgent >> /var/log/aetherix-puku.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v 'puku run' ; echo "$CRON_LINE" ) | crontab -
  sudo touch /var/log/aetherix-puku.log
  sudo chown "$USER":"$USER" /var/log/aetherix-puku.log
  ok "Cron installed: '${CRON_LINE}'"
}

# ---------- 8. firewall + summary ----------
firewall_basics() {
  step "Configuring UFW (SSH + Cloudflare-only egress)"
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow from 127.0.0.1 to any port 8000 proto tcp comment "aetherix backend (local only)"
  sudo ufw --force enable
  ok "UFW active"
}

summary() {
  step "${GREEN}Aetherix bootstrap complete${NC}"
  cat <<EOF

  ${BOLD}What was installed${NC}
  • Docker + Compose plugin
  • Puku CLI stub on host (replace with real Puku when available)
  • FVM + latest stable Flutter
  • Repo cloned to ${INSTALL_DIR}
  • .env generated with random secrets (edit before going live)
  • Containers: postgres, backend, cloudflared
  • Cron: ${SCHEDULER_CRON} → puku run

  ${BOLD}Next steps${NC}
  1. ssh ${USER}@<vps>  →  cd ${INSTALL_DIR}
  2. Edit .env and set CLOUDFLARE_TUNNEL_TOKEN + DOMAIN.
  3. sudo docker compose up -d --build cloudflared
  4. Verify backend:  curl -s http://127.0.0.1:8000/api/v1/health
  5. Watch logs:      sudo docker compose logs -f backend
  6. Puku logs:       tail -f /var/log/aetherix-puku.log

  ${BOLD}Flutter on the VPS${NC}
  fvm use stable
  cd flutter/Aetherix_app
  fvm flutter pub get
  fvm flutter build apk --release           # Android
  fvm flutter build windows --release       # Windows desktop

EOF
}

main() {
  require_root
  detect_os
  install_packages
  install_docker
  install_puku
  install_fvm_flutter
  clone_repo
  ensure_env
  firewall_basics
  bring_up_containers
  install_cron
  summary
}

main "$@"