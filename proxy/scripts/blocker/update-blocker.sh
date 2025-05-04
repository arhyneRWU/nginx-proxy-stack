#!/usr/bin/env bash
set -euo pipefail

# scripts/blocker/update-blocker.sh
# —————————————————————————————————————————————
# Clone (if needed) or pull latest BotBlocker rules, test nginx config, and reload

# 1) Figure out our project root (script lives in PROJECT_ROOT/scripts/blocker/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

mkdir -p "$PROJECT_ROOT/botblocker"
# 2) Repo details
REPO_PARENT="$PROJECT_ROOT/botblocker"
REPO_DIR="$REPO_PARENT/repo"
REPO_URL="https://github.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker.git"
PROXY_CONTAINER="nginx-proxy"

# 3) Ensure parent directory exists
mkdir -p "$PROJECT_ROOT/botblocker/repo"

# 4) Clone if first run (or if repo exists but no .git), otherwise pull updates
REPO_PATH="$PROJECT_ROOT/botblocker/repo"
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "\0x27A4 First\0x2010time setup of BotBlocker\0x2026"
  # If an old repo directory (without .git) exists, remove it
  if [ -d "$REPO_PATH" ]; then
    echo "  Removing stale directory $REPO_PATH"
    rm -rf "$REPO_PATH"
  fi
  echo "Cloning BotBlocker into $REPO_PATH\0x2026"
  git clone --depth 1 "$REPO_URL" "$REPO_PATH"
else
  echo "Pulling latest BotBlocker\0x2026"
  git -C "$REPO_PATH" pull --ff-only
fi