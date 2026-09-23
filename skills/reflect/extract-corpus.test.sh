#!/usr/bin/env bash
# Self-check for extract-corpus.sh's no-match path: it must list every project dir from both roots, once each.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.claude/projects/-a-live" "$tmp/home/.claude/projects/-a-shared" \
         "$tmp/backup/-a-mirror" "$tmp/backup/-a-shared"

err="$(HOME="$tmp/home" REFLECT_BACKUP_DIR="$tmp/backup" bash "$here/extract-corpus.sh" zzz-no-match "$tmp/out" 2>&1 >/dev/null)"
code=$?

fail=0
[ "$code" -eq 1 ] || { echo "FAIL: exit $code, want 1"; fail=1; }
case "$err" in *"unbound variable"*) echo "FAIL: unbound variable"; fail=1 ;; esac
for d in -a-live -a-mirror -a-shared; do
  n="$(printf '%s\n' "$err" | grep -cx -- "$d")"
  [ "$n" -eq 1 ] || { echo "FAIL: $d listed $n times, want 1"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "PASS"
exit "$fail"
