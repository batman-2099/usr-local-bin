#!/usr/bin/env bash
# Automatically commit docker-compose changes in /srv/docker

WATCH_DIR="/srv/docker"
REPO_DIR="/srv/docker"
BRANCH="main"
LOG_FILE="/var/log/git-auto-commit.log"

cd "$REPO_DIR" || exit 1

echo "[$(date)] Git auto-commit service started for $WATCH_DIR" >> "$LOG_FILE"

# Watch for compose file changes
inotifywait -m -r -e modify,create,delete,move \
  --format '%w%f' "$WATCH_DIR" | while read -r FILE; do
    if [[ "$FILE" == *.yml || "$FILE" == *.yaml ]]; then
        echo "[$(date)] Change detected in $FILE" >> "$LOG_FILE"
        git add "$FILE"
        git commit -m "Auto commit: updated $(basename "$FILE") on $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
        git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
    fi
done
