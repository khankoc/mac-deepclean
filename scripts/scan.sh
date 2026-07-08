#!/bin/bash
# mac-deepclean scanner. Measures and gathers context. NEVER deletes anything.
# Output: JSON on stdout. Sizes in KB.
# Env: DEEPCLEAN_MIN_MB (default 100), DEEPCLEAN_ROOTS (colon-separated override),
#      DEEPCLEAN_HOME, DEEPCLEAN_CODE_DIRS (colon-separated project roots).
set -u

MIN_MB="${DEEPCLEAN_MIN_MB:-100}"
MIN_KB=$((MIN_MB * 1024))
HOME_DIR="${DEEPCLEAN_HOME:-$HOME}"

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

FIRST=1
emit() { # $1=path $2=size_kb $3=category $4=extra json fields (each starting with a comma) or ""
  local p
  p=$(json_escape "$1")
  if [ "$FIRST" -eq 1 ]; then FIRST=0; else printf ','; fi
  printf '\n  {"path":"%s","size_kb":%s,"category":"%s"%s}' "$p" "$2" "$3" "$4"
}

size_kb() { du -sk "$1" 2>/dev/null | awk '{print $1}'; }

mtime_iso() { stat -f '%Sm' -t '%Y-%m-%d' "$1" 2>/dev/null || echo "unknown"; }

scan_children() { # $1=root dir, $2=category label
  local root="$1" cat="$2" child kb extra
  [ -d "$root" ] || return 0
  for child in "$root"/* "$root"/.[!.]*; do
    [ -e "$child" ] || continue
    kb=$(size_kb "$child")
    [ -n "$kb" ] || continue
    [ "$kb" -ge "$MIN_KB" ] || continue
    extra=",\"last_modified\":\"$(mtime_iso "$child")\""
    emit "$child" "$kb" "$cat" "$extra"
  done
}

printf '{\n "scanned_at":"%s",\n "min_mb":%s,\n "items":[' "$(date '+%Y-%m-%dT%H:%M:%S')" "$MIN_MB"

if [ -n "${DEEPCLEAN_ROOTS:-}" ]; then
  OLDIFS=$IFS; IFS=':'
  for r in $DEEPCLEAN_ROOTS; do
    IFS=$OLDIFS
    scan_children "$r" "discovered"
    IFS=':'
  done
  IFS=$OLDIFS
else
  scan_children "$HOME_DIR" "home"
  scan_children "$HOME_DIR/Library/Caches" "user_cache"
  scan_children "$HOME_DIR/Library/Application Support" "app_support"
  scan_children "$HOME_DIR/Library/Containers" "container"
  scan_children "$HOME_DIR/Library/Group Containers" "container"
  scan_children "$HOME_DIR/Library/Developer" "developer"
  scan_children "$HOME_DIR/Library/Logs" "logs"
  scan_children "/Library/Developer" "developer_system"
  scan_children "/Library/Caches" "system_cache"
  scan_children "/Applications" "application"
  scan_children "/private/var/folders" "system_temp"
fi

printf '\n ]\n}\n'
