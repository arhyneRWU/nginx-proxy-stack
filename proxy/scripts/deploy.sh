#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy.sh
# —————————————————————————————————————————————
# Single‑point deploy script.  By default runs the TEST stack.
# Pass "--prod" to run the PRODUCTION stack and install cron jobs.

usage() {
  cat <<EOF
Usage: $(basename "$0") [--prod]

Options:
  --prod     Deploy to production (uses docker-compose.production.yml
             and installs cron jobs)
  -h|--help  Show this help and exit
EOF
  exit 1
}

# 0) Parse args
MODE="test"
for arg in "$@"; do
  case "$arg" in
    --prod) MODE="prod"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $arg" >&2; usage ;;
  esac
done

# 1) Locate repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# 2) Ensure external Docker network “webnet” exists
if ! docker network inspect webnet >/dev/null 2>&1; then
  echo "▶ Creating external network: webnet"
  docker network create webnet
fi

# 3) Activate venv if present
if [[ -f venv/bin/activate ]]; then
  echo "▶ Activating virtual environment"
  source venv/bin/activate
fi

# 4) Install Python deps for config generation
echo "▶ Installing Python packages"
python3 -m pip install --no-cache-dir jinja2 pyyaml

# 5) Make helper scripts executable
echo "▶ Fixing execute bits on helpers"
chmod +x scripts/certs/generate-dummy-certs.sh
chmod +x scripts/blocker/update-blocker.sh
chmod +x scripts/cron/install-cron-jobs.sh

bash ./scripts/blocker/update-blocker.sh

# 6) Regenerate Nginx configs
echo "▶ Regenerating configs"
if [[ "$MODE" == "test" ]]; then
  python3 scripts/config/generate-configs.py \
    --domains-config config/domains.yml \
    --templates-dir config/templates \
    --output-dir nginx/sites-enabled \
    --clean
else
  python3 scripts/config/generate-configs.py \
    --domains-config config/domains.yml \
    --templates-dir config/templates \
    --output-dir nginx/sites-enabled
fi

# 6b) Ensure SSL certs exist—generate dummy ones only if missing
echo "▶ Ensuring SSL certificates (dummy where needed)"
bash scripts/certs/generate-dummy-certs.sh \
  --nginx-conf-dir nginx/sites-enabled \
  --cert-live-dir certbot/conf/live

# 7) Choose compose file
if [[ "$MODE" == "prod" ]]; then
  COMPOSE_FILE="docker-compose.production.yml"
else
  echo "⚠️  TEST mode: down/up the test stack"
  COMPOSE_FILE="docker-compose.test.yml"
fi

# 8) Tear down existing stack
echo "▶ Tearing down existing stack ($MODE)"
docker compose -f "$COMPOSE_FILE" down

# 9) Build & start
echo "▶ Building & starting stack ($MODE)"
docker compose -f "$COMPOSE_FILE" up --build -d proxy

# 10) Show status
echo "▶ Proxy status ($MODE):"
docker compose -f "$COMPOSE_FILE" ps proxy

# 11) In production, install cron jobs
if [[ "$MODE" == "prod" ]]; then
  echo "▶ Installing cron jobs for production"
  scripts/cron/install-cron-jobs.sh
fi

# 12) Rotate logs
echo "▶ Rotating logs via project‑local logrotate.conf"
LOGROTATE_CONF="$REPO_ROOT/scripts/maintenance/logrotate/logrotate.conf"
LOGROTATE_STATE="$REPO_ROOT/scripts/maintenance/logrotate/logrotate.state"
if [[ ! -f "$LOGROTATE_CONF" ]]; then
  echo "❌ logrotate.conf not found at $LOGROTATE_CONF" >&2
  exit 1
fi
logrotate -s "$LOGROTATE_STATE" "$LOGROTATE_CONF"

echo "🚀 Deployment ($MODE) complete."
if [[ "$MODE" == "test" ]]; then
  echo " Next steps:"
  echo "   • To install cron jobs for production, re-run with --prod"
else
  echo "✓ Cron jobs installed"
  echo "✓ Remember to run scripts/blocker/update-blocker.sh regularly"
fi
