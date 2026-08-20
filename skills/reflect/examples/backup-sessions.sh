#!/bin/sh
# Example: accumulating local mirror of Claude Code session state.
#
# reflect reads this mirror as a second corpus root, because Claude Code
# hard-deletes transcripts once they age past cleanupPeriodDays (30 by default,
# shorter under org policy). Without a mirror, reflect can only ever see the
# recent window.
#
# rsync WITHOUT --delete is the whole point: reaped sessions and accidental
# wipes survive here. Never add --delete.
#
# Install as a scheduled job (hourly is plenty):
#   launchd user agent (macOS) or systemd user timer (Linux); cron works too.
#   crontab -e  ->  0 * * * * $HOME/.local/bin/backup-sessions.sh
set -eu

DEST="${CLAUDE_SESSION_BACKUP_DIR:-$HOME/.claude-session-backups}"
RETENTION_DAYS="${CLAUDE_SESSION_BACKUP_RETENTION_DAYS:-0}"

mkdir -p "$DEST"

# projects/ holds the transcripts reflect mines; the rest is state worth keeping.
# Deliberately excluded: plugins/, skills/, CLAUDE.md (reinstallable or config-
# managed) and cache/scratch dirs (paste-cache, uploads, shell-snapshots).
for src in projects file-history plans todos sessions \
           memory.jsonl history.jsonl settings.json settings.local.json keybindings.json; do
  [ ! -e "$HOME/.claude/$src" ] || rsync -a "$HOME/.claude/$src" "$DEST/"
done

# 0 = keep forever, which is the default: outliving Claude's own retention is
# the reason this exists.
if [ "$RETENTION_DAYS" -gt 0 ]; then
  find "$DEST" -type f -mtime "+$RETENTION_DAYS" -delete
fi
