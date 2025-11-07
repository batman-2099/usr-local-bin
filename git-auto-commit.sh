#!/usr/bin/env bash
# Automatically commit and push docker-compose changes in /srv/docker
# Handles additions, deletions, and modifications.

set -Eeuo pipefail

WATCH_DIR="/srv/docker"
REPO_DIR="/srv/docker"
BRANCH="main"
LOG_FILE="/var/log/git-auto-commit.log"

cd "$REPO_DIR" || exit 1
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] Git auto-commit service started for $WATCH_DIR" >> "$LOG_FILE"

# Ensure repo is marked safe (prevents "dubious ownership" errors)
git config --global --add safe.directory "$REPO_DIR"

# Watch for create, delete, modify, and move events
inotifywait -m -r -e modify,create,delete,move \
  --format '%e %w%f' "$WATCH_DIR" | while read -r EVENT FILE; do
    # Only act on docker-compose files
    if [[ "$FILE" == *.yml || "$FILE" == *.yaml ]]; then
        echo "[$(date)] Event: $EVENT | File: $FILE" >> "$LOG_FILE"

        # Stage all changes (adds, deletes, renames, updates)
        git add -A

        # Commit if something changed
        if ! git diff --cached --quiet; then
            git commit -m "Auto commit: $EVENT $(basename "$FILE") on $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1 || true
            git push origin "$BRANCH" >> "$LOG_FILE" 2>&1 || echo "[$(date)] Push failed" >> "$LOG_FILE"
        else
            echo "[$(date)] No changes to commit." >> "$LOG_FILE"
