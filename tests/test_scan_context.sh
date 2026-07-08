#!/bin/bash
set -u
cd "$(dirname "$0")/.."
FAILED=0
fail() { echo "FAIL: $1"; FAILED=1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture 1: a git repo WITHOUT remote, with a dirty file and a big node_modules
mkdir -p "$TMP/code/myapp/node_modules"
git -C "$TMP/code/myapp" init -q
echo "uncommitted" > "$TMP/code/myapp/notes.txt"
dd if=/dev/zero of="$TMP/code/myapp/node_modules/blob" bs=1024 count=2048 2>/dev/null

# Fixture 2: a fake orphaned tool dir ~/.ghosttool (no such CLI on PATH)
mkdir -p "$TMP/fakehome/.ghosttool"
dd if=/dev/zero of="$TMP/fakehome/.ghosttool/store" bs=1024 count=2048 2>/dev/null

OUT=$(DEEPCLEAN_MIN_MB=1 DEEPCLEAN_HOME="$TMP/fakehome" \
      DEEPCLEAN_CODE_DIRS="$TMP/code" /bin/bash scripts/scan.sh)

if ! printf '%s' "$OUT" | python3 -m json.tool >/dev/null 2>&1; then
  fail "output is not valid JSON"
fi
# node_modules reported as project_artifact with git context: no remote, dirty
CHECK=$(printf '%s' "$OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
a=[i for i in d['items'] if i['category']=='project_artifact' and i['path'].endswith('node_modules')]
if not a: print('missing'); raise SystemExit
g=a[0].get('git',{})
print('ok' if (g.get('has_remote')==False and g.get('dirty_files',0)>=1 and g.get('synced_with_remote')==False) else 'badgit')
")
[ "$CHECK" = "ok" ] || fail "node_modules git context wrong: $CHECK"

# orphaned hidden tool dir carries cli_installed:false
CHECK2=$(printf '%s' "$OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
a=[i for i in d['items'] if i['path'].endswith('.ghosttool')]
print('ok' if (a and a[0].get('cli_installed') is False) else 'bad')
")
[ "$CHECK2" = "ok" ] || fail "orphan cli_installed flag wrong: $CHECK2"

[ "$FAILED" -eq 0 ] && echo "PASS: scanner context"
exit "$FAILED"
