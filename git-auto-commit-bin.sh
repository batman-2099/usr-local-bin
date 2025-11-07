#!/usr/bin/env bash
# Auto-commit and push /usr/local/bin changes to GitHub

set -Eeuo pipefail

REPO_DIR="/usr/local/bin"
LOG_FILE="/var/log/git-auto-commit-bin.log"
BRANCH="main"

mkdir -p "$(dirname "$LOG_FILE")"
echo "[$(date)] Starting auto-commit watcher for $REPO_DIR" >> "$LOG_FILE"

# Make sure the repo exists
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "[$(date)] ERROR: No Git repo found in $REPO_DIR" >> "$LOG_FILE"
  exit 1
fi

git -C "$REPO_DIR" config --global --add safe.directory "$REPO_DIR"

inotifywait -m -r -e modify,create,delete,move "$REPO_DIR" \
  --format '%e %w%f' | while read -r EVENT FILE; do
    [[ "$FILE" == *.swp || "$FILE" == *.tmp || "$FILE" == *.lock ]] && continue

    echo "[$(date)] Event: $EVENT | File: $FILE" >> "$LOG_FILE"

    (
      cd "$REPO_DIR" || exit 1
      git add -A
      if ! git diff --cached --quiet; then
        git commit -m "Auto commit: $EVENT $(basename "$FILE") on $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1 || true
        git push origin "$BRANCH" >> "$LOG_FILE" 2>&1 || echo "[$(date)] Push failed" >> "$LOG_FILE"
      else
        echo "[$(date)] No changes to commit." >> "$LOG_FILE"
      fi
    )
done
