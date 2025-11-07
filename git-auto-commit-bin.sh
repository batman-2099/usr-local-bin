#!/usr/bin/env bash
# Auto-commit and push /usr/local/bin changes to GitHub
# by Patrick @ bat-nas

set -Eeuo pipefail

WATCH_DIR="/usr/local/bin"
REPO_DIR="/srv/git/usr-local-bin"
LOG_FILE="/var/log/git-auto-commit-bin.log"
BRANCH="main"

mkdir -p "$(dirname "$LOG_FILE")"
echo "[$(date)] Starting auto-commit watcher for $WATCH_DIR" >> "$LOG_FILE"

# Ensure repo exists
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "[$(date)] ERROR: No Git repo found at $REPO_DIR" >> "$LOG_FILE"
  exit 1
fi

# Mark repo as safe
git -C "$REPO_DIR" config --global --add safe.directory "$REPO_DIR"

# Start watching for create, modify, move, and delete events
inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" \
  --format '%e %w%f' | while read -r EVENT FILE; do
    # Skip temp or lock files
    [[ "$FILE" == *.swp || "$FILE" == *.tmp || "$FILE" == *.lock ]] && continue

    echo "[$(date)] Event: $EVENT | File: $FILE" >> "$LOG_FILE"

    # Sync /usr/local/bin -> repo
    rsync -a --delete "$WATCH_DIR"/ "$REPO_DIR"/

    (
      cd "$REPO_DIR" || exit 1
      git add -A

      # If something actually changed, commit and push
      if ! git diff --cached --quiet; then
        git commit -m "Auto commit: $EVENT $(basename "$FILE") on $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1 || true
        git push origin "$BRANCH" >> "$LOG_FILE" 2>&1 || echo "[$(date)] Push failed" >> "$LOG_FILE"
      else
        echo "[$(date)] No changes to commit." >> "$LOG_FILE"
      fi
    )
done
