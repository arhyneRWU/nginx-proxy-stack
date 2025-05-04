#!/usr/bin/env bash
set -euo pipefail

# scripts/cron/install-cron-jobs.sh
# —————————————————————————————————————————————
# Installs cron entries:
#   • Twice‑daily blocker rule updates
#   • Daily log rotation

# 1) Compute project root (assuming this script is in PROJECT_ROOT/scripts/cron/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 2) Locate logrotate binary
LOGROTATE_CMD="$(command -v logrotate)"
if [[ -z "$LOGROTATE_CMD" ]]; then
  echo "❌ logrotate not found in PATH. Please install logrotate." >&2
  exit 1
fi

# 3) Paths
BLOCKER_SCRIPT="$PROJECT_ROOT/scripts/blocker/update-blocker.sh"
BLOCKER_LOG="$PROJECT_ROOT/botblocker-update.log"
LOGROTATE_CONF="$PROJECT_ROOT/scripts/maintenance/logrotate/logrotate.conf"
LOGROTATE_STATE="$PROJECT_ROOT/scripts/maintenance/logrotate/logrotate.state"
LOGROTATE_LOG="$PROJECT_ROOT/logrotate.log"

# 4) Cron lines
CRON_BLOCKER="0 */12 * * * cd $PROJECT_ROOT && $BLOCKER_SCRIPT >> $BLOCKER_LOG 2>&1"
CRON_LOGROTATE="0 3 * * * $LOGROTATE_CMD -s $LOGROTATE_STATE $LOGROTATE_CONF >> $LOGROTATE_LOG 2>&1"

# 5) Install, removing old entries
{
  crontab -l 2>/dev/null || true
} \
  | grep -v '[u]pdate-blocker\.sh' \
  | grep -v "[l]ogrotate -s" \
  | { cat; echo "$CRON_BLOCKER"; echo "$CRON_LOGROTATE"; } \
  | crontab -

echo "✔ Installed cron jobs:"
echo "    $CRON_BLOCKER"
echo "    $CRON_LOGROTATE"
echo "✔ Logs will go to:"
echo "    • Blocker: $BLOCKER_LOG"
echo "    • Logrotate: $LOGROTATE_LOG"
