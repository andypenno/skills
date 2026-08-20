#!/usr/bin/env bash
# reflect: extract the user's own typed utterances from Claude Code session
# transcripts, collapsing GBs of JSONL into a small, signal-dense corpus.
# Skips tool results, system-reminders, slash-command wrappers, and subagent
# sidechains (those "user" messages are prompts the agent wrote, not the human).
#
# Usage: extract-corpus.sh [PROJECT] [OUTDIR]
#   PROJECT  which sessions to mine. One of:
#              - "" or "all"        -> every project
#              - an exact dir name under ~/.claude/projects (e.g. -Users-me-Workspace-foo)
#              - an absolute path   (e.g. /Users/me/Workspace/foo) -> slugified to the dir name
#              - a substring        -> matches any project dir containing it (case-insensitive)
#   OUTDIR   where chunk files + manifest.json land (default: ~/.claude/.cache/reflect)
#
# Sources both the live transcript dir and, when it exists, a backup mirror
# (default ~/.claude-session-backups/projects, override with REFLECT_BACKUP_DIR).
# Claude Code hard-deletes transcripts past cleanupPeriodDays, so the mirror is
# usually the only place old sessions still exist. Union by session id, live wins.
#
# Output: OUTDIR/chunk-NNN.txt (size-bounded), OUTDIR/manifest.json, OUTDIR/stats.txt
#
# Requires: jq and awk (both POSIX-portable). bash 3.2+, plus find/date/stat
# (BSD and GNU variants are both handled). No python required.
set -euo pipefail

# Preflight: fail loudly on a missing hard dependency rather than silently
# producing an empty corpus (jq errors are otherwise swallowed per-file below).
for dep in jq awk; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "reflect: required command '$dep' not found - install it and retry" >&2
    echo "        (macOS: brew install $dep · Debian/Ubuntu: sudo apt install $dep)" >&2
    exit 1
  }
done

PROJECT="${1:-all}"
OUTDIR="${2:-$HOME/.claude/.cache/reflect}"
LIVE_ROOT="$HOME/.claude/projects"
BACKUP_ROOT="${REFLECT_BACKUP_DIR:-$HOME/.claude-session-backups/projects}"
CHUNK_BYTES=$((120 * 1024))   # ~120KB of text per chunk -> comfortable agent context
MAX_UTTER=500                 # truncate any single utterance to this many chars

# Live root first: when a session exists in both, the live copy is authoritative
# and the mirror's copy is skipped (see the seen-sid guard below).
ROOTS=()
[ -d "$LIVE_ROOT" ] && ROOTS+=("$LIVE_ROOT")
[ -d "$BACKUP_ROOT" ] && ROOTS+=("$BACKUP_ROOT")
if [ "${#ROOTS[@]}" -eq 0 ]; then
  echo "No session directory at $LIVE_ROOT or $BACKUP_ROOT" >&2
  exit 1
fi

# Resolve PROJECT to a list of session directories, across every root.
resolve_dirs() {
  local p="$1" root slug matches
  for root in "${ROOTS[@]}"; do
    if [ -z "$p" ] || [ "$p" = "all" ]; then
      find "$root" -mindepth 1 -maxdepth 1 -type d
      continue
    fi
    # absolute path -> slug (Claude Code replaces "/" with "-")
    slug="${p//\//-}"
    if [ -d "$root/$slug" ]; then echo "$root/$slug"; continue; fi
    if [ -d "$root/$p" ]; then echo "$root/$p"; continue; fi
    # substring match (case-insensitive)
    matches="$(find "$root" -mindepth 1 -maxdepth 1 -type d -iname "*$p*")"
    [ -n "$matches" ] && echo "$matches"
  done
}

DIRS=()
while IFS= read -r line; do
  [ -n "$line" ] && DIRS+=("$line")
done < <(resolve_dirs "$PROJECT")
if [ "${#DIRS[@]}" -eq 0 ] || [ -z "${DIRS[0]:-}" ]; then
  echo "No project sessions matched '$PROJECT'. Available:" >&2
  find "$ROOT" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; >&2
  exit 1
fi

case "$OUTDIR" in
  ""|/|"$HOME") echo "reflect: refusing to wipe unsafe OUTDIR '$OUTDIR'" >&2; exit 1 ;;
esac
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
RAW="$OUTDIR/_corpus.txt"; : > "$RAW"
# Session ids already ingested. A flat file, not an associative array: macOS
# ships bash 3.2, which has no declare -A.
SEEN="$OUTDIR/.seen-sids"; : > "$SEEN"

# jq: one line per genuine user utterance.
# - role=user text blocks that are real human input (not sidechain/meta)
# - drop blocks starting with '<' (system-reminder, command-*, local-command-stdout, bash tags)
# - normalise any interruption to an [INTERRUPTED] marker (a strong friction signal)
# - collapse internal newlines so every utterance is a single line
read -r -d '' JQ <<'JQEOF' || true
select(.type=="user" and (.isSidechain|not) and (.isMeta|not))
| .message.content as $c
| ( if ($c|type)=="string" then [$c]
    else [ $c[] | select(.type=="text") | .text ] end )
| .[]
| select(type=="string")
| gsub("\r";"") | gsub("\n";" ") | gsub(" +";" ") | gsub("^ +| +$";"")
| select(length>0)
| if startswith("[Request interrupted by user") then "[INTERRUPTED]"
  elif startswith("<") then empty
  else . end
JQEOF

sessions=0; utterances=0; dupes=0
for proj in "${DIRS[@]}"; do
  pname="$(basename "$proj")"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    epoch="$(stat -f%m "$f" 2>/dev/null || stat -c%Y "$f" 2>/dev/null || echo 0)"
    day="$(date -r "$epoch" +%Y-%m-%d 2>/dev/null || date -d "@$epoch" +%Y-%m-%d 2>/dev/null || echo unknown)"
    sid="$(basename "$f" .jsonl)"
    if grep -qxF "$sid" "$SEEN" 2>/dev/null; then dupes=$((dupes+1)); continue; fi
    printf '%s\n' "$sid" >> "$SEEN"
    lines="$(jq -r "$JQ" "$f" 2>/dev/null || true)"
    [ -z "$lines" ] && continue
    {
      printf '### SESSION %s | project %s | date %s\n' "$sid" "$pname" "$day"
      while IFS= read -r u; do
        [ -z "$u" ] && continue
        [ "${#u}" -gt "$MAX_UTTER" ] && u="${u:0:$MAX_UTTER} …[truncated]"
        printf -- '- %s\n' "$u"; utterances=$((utterances+1))
      done <<< "$lines"
      printf '\n'
    } >> "$RAW"
    sessions=$((sessions+1))
  done < <(find "$proj" -name '*.jsonl' -type f 2>/dev/null)
done

# Shard into size-bounded chunks, never splitting a session block. awk (not
# python) keeps the dep list to jq+awk, and its line-anchored ^### SESSION split
# is more robust than a substring split if a user ever pasted that marker.
rm -f "$OUTDIR"/chunk-*.txt
awk -v out="$OUTDIR" -v lim="$CHUNK_BYTES" '
  function emit() {
    if (block == "") return
    if (chunklen > 0 && chunklen + blocklen > lim) {
      idx++; fn = sprintf("%s/chunk-%03d.txt", out, idx)
      printf "%s", chunk > fn; close(fn); chunk = ""; chunklen = 0
    }
    chunk = chunk block; chunklen += blocklen; block = ""; blocklen = 0
  }
  /^### SESSION / { emit() }
  { block = block $0 ORS; blocklen += length($0) + 1 }
  END {
    emit()
    if (chunk != "") { idx++; fn = sprintf("%s/chunk-%03d.txt", out, idx); printf "%s", chunk > fn; close(fn) }
  }
' "$RAW"

# Build manifest.json from the chunk files just written.
{
  printf '{\n  "chunks": ['
  i=0
  for c in "$OUTDIR"/chunk-*.txt; do
    [ -e "$c" ] || continue
    [ "$i" -gt 0 ] && printf ','
    printf '\n    "%s"' "$c"
    i=$((i + 1))
  done
  printf '\n  ],\n  "count": %d\n}\n' "$i"
} > "$OUTDIR/manifest.json"

corpus_bytes=$(stat -f%z "$RAW" 2>/dev/null || stat -c%s "$RAW" 2>/dev/null || echo 0)
rm -f "$SEEN"
{
  echo "project_filter=$PROJECT"
  echo "roots=${ROOTS[*]}"
  echo "session_dirs=${#DIRS[@]}"
  echo "sessions_with_user_text=$sessions"
  echo "duplicate_sessions_skipped=$dupes"
  echo "utterances=$utterances"
  echo "corpus_bytes=$corpus_bytes"
  awk -v b="$corpus_bytes" 'BEGIN{printf "corpus_mb=%.2f\n", b/1048576}'
  echo "chunks=$(ls "$OUTDIR"/chunk-*.txt 2>/dev/null | wc -l | tr -d ' ')"
  echo "outdir=$OUTDIR"
} | tee "$OUTDIR/stats.txt"
