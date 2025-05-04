#!/usr/bin/env bash
set -euo pipefail
trap 'echo "⚠️  Error on line $LINENO" >&2' ERR

# generate-dummy-certs.sh — create self-signed certificates for each server_name
# Usage: generate-dummy-certs.sh [--nginx-conf-dir PATH] [--cert-live-dir PATH]

# Compute script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Where our generated nginx .conf files live
NGINX_CONF_DIR="$PROJECT_ROOT/nginx/sites-enabled"

# Where we want to write dummy certs under project root
CERT_LIVE_DIR="$PROJECT_ROOT/certbot/conf/live"

# ———————— DEBUG OUTPUT ————————
echo "DEBUG: SCRIPT_DIR     = $SCRIPT_DIR"
echo "DEBUG: PROJECT_ROOT   = $PROJECT_ROOT"
echo "DEBUG: NGINX_CONF_DIR = $NGINX_CONF_DIR"
echo "DEBUG: CERT_LIVE_DIR  = $CERT_LIVE_DIR"
echo "------------------------------------"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --nginx-conf-dir)
      NGINX_CONF_DIR="$2"; shift 2 ;;
    --cert-live-dir)
      CERT_LIVE_DIR="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--nginx-conf-dir PATH] [--cert-live-dir PATH]
EOF
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1 ;;
  esac
done

# Ensure openssl is installed
if ! command -v openssl &>/dev/null; then
  echo "❌ openssl not found in PATH. Please install it first." >&2
  exit 1
fi

shopt -s nullglob
for conf in "$NGINX_CONF_DIR"/*.conf; do
  echo "➤ Processing $conf …"

  # 1) Extract everything after "server_name" up to the semicolon
  raw_names=$(grep -E '^[[:space:]]*server_name[[:space:]]+' "$conf" \
              | sed -E 's/^[[:space:]]*server_name[[:space:]]+([^;]+);.*/\1/')
  echo "DEBUG: raw_names = \"$raw_names\""

  # 2) Split raw_names into an array of domains
  read -r -a domains <<< "$raw_names"
  echo "DEBUG: domains   = (${domains[*]})"

  # 3) Loop over each domain
  for domain in "${domains[@]}"; do
    live_dir="$CERT_LIVE_DIR/$domain"
    key_file="$live_dir/privkey.pem"
    cert_file="$live_dir/fullchain.pem"

    if [[ -f "$key_file" && -f "$cert_file" ]]; then
      echo "✔ Certificate exists for $domain, skipping."
      continue
    fi

    echo "🔐 Generating dummy certificate for $domain"
    mkdir -p "$live_dir"
    openssl req -x509 -nodes \
      -newkey rsa:4096 \
      -days 365 \
      -keyout  "$key_file" \
      -out     "$cert_file" \
      -subj   "/CN=$domain"
  done
done

echo "✅ Done generating dummy certificates."
