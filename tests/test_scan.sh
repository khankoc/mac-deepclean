#!/bin/bash
# Tests for scripts/scan.sh — plain sh assertions, no framework.
set -u
cd "$(dirname "$0")/.."
FAILED=0
fail() { echo "FAIL: $1"; FAILED=1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixtures: one dir above threshold, one below
mkdir -p "$TMP/bigdir" "$TMP/smalldir"
dd if=/dev/zero of="$TMP/bigdir/blob" bs=1024 count=2048 2>/dev/null   # 2 MB
dd if=/dev/zero of="$TMP/smalldir/tiny" bs=1024 count=10 2>/dev/null   # 10 KB

OUT=$(DEEPCLEAN_MIN_MB=1 DEEPCLEAN_ROOTS="$TMP" /bin/bash scripts/scan.sh)

# 1. Output is valid JSON
if ! printf '%s' "$OUT" | python3 -m json.tool >/dev/null 2>&1; then
  fail "output is not valid JSON"
fi
# 2. Big dir found
if ! printf '%s' "$OUT" | grep -q '"path":".*bigdir"'; then
  fail "bigdir not reported"
fi
# 3. Small dir filtered out
if printf '%s' "$OUT" | grep -q 'smalldir'; then
  fail "smalldir should be below threshold"
fi
# 4. size_kb is a number >= 2000 for bigdir
SIZE=$(printf '%s' "$OUT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(next(i['size_kb'] for i in d['items'] if i['path'].endswith('bigdir')))
")
if [ "$SIZE" -lt 2000 ]; then
  fail "bigdir size_kb=$SIZE, expected >= 2000"
fi

[ "$FAILED" -eq 0 ] && echo "PASS: scanner core"
exit "$FAILED"
