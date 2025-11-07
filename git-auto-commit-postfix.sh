#!/usr/bin/env bash
# Auto-commit Postfix configuration changes

WATCH_DIR="/etc/postfix"
REPO_DIR="/srv/git/postfix-config"
LOG_FILE="/var/log/git-auto-commit-postfix.log"
BRANCH="main"

mkdir -p "$(dirname "$LOG_FILE")"
echo "[$(date)] Starting Postfix Git auto-commit watcher for $WATCH_DIR" >> "$LOG_FILE"

# Ensure the repo exists and is safe
git -C "$REPO_DIR" config --global --add safe.directory "$REPO_DIR"

inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" \
  --format '%w%f' | while read -r FILE; do
    if [[ "$FILE" == *.cf || "$FILE" == *.map || "$FILE" == main.cf || "$FILE" == master.cf ]]; then
        echo "[$(date)] Change detected in $FILE" >> "$LOG_FILE"

        # Sync /etc/postfix → repo
        rsync -a --delete "$WATCH_DIR"/ "$REPO_DIR"/

        cd "$REPO_DIR" || exit 1
        git add .
        git diff --cached --quiet || git commit -m "Auto commit: updated $(basename "$FILE") on $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
        git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
    fi
done
