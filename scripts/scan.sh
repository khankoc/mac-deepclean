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

git_context() { # $1=dir that is (or is inside) a git repo → prints json fields or nothing
  local d="$1"
  while [ "$d" != "/" ] && [ ! -d "$d/.git" ]; do d=$(dirname "$d"); done
  [ -d "$d/.git" ] || return 0
  local dirty remote synced counts
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  remote=$(git -C "$d" remote 2>/dev/null | head -1)
  if [ -n "$remote" ]; then
    counts=$(git -C "$d" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null | tr -s ' \t' ' ')
    if [ "$counts" = "0 0" ] && [ "$dirty" = "0" ]; then synced=true; else synced=false; fi
    printf ',"git":{"has_remote":true,"dirty_files":%s,"synced_with_remote":%s}' "$dirty" "$synced"
  else
    printf ',"git":{"has_remote":false,"dirty_files":%s,"synced_with_remote":false}' "$dirty"
  fi
}

cli_context() { # $1=hidden dir like /home/.pnpm → prints ,"cli_installed":bool
  local name
  name=$(basename "$1")
  name="${name#.}"
  if command -v "$name" >/dev/null 2>&1; then
    printf ',"cli_installed":true'
  else
    printf ',"cli_installed":false'
  fi
}

scan_artifacts() {
  local roots="${DEEPCLEAN_CODE_DIRS:-$HOME_DIR/Documents:$HOME_DIR/Desktop:$HOME_DIR/Developer:$HOME_DIR/Projects:$HOME_DIR/code:$HOME_DIR/dev:$HOME_DIR/src:$HOME_DIR/workspace:$HOME_DIR/GitHub:$HOME_DIR/repos}"
  local root d kb extra
  OLDIFS=$IFS; IFS=':'
  for root in $roots; do
    IFS=$OLDIFS
    [ -d "$root" ] || { IFS=':'; continue; }
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      kb=$(size_kb "$d")
      [ -n "$kb" ] || continue
      [ "$kb" -ge "$MIN_KB" ] || continue
      extra=",\"last_modified\":\"$(mtime_iso "$d")\"$(git_context "$d")"
      emit "$d" "$kb" "project_artifact" "$extra"
    done < <(find "$root" -maxdepth 6 -type d \
      \( -name node_modules -o -name .next -o -name dist -o -name build \
         -o -name .dart_tool -o -name venv -o -name .venv -o -name target -o -name out \) \
      -prune 2>/dev/null)
    IFS=':'
  done
  IFS=$OLDIFS
}

scan_children() { # $1=root dir, $2=category label
  local root="$1" cat="$2" child kb extra
  [ -d "$root" ] || return 0
  for child in "$root"/* "$root"/.[!.]*; do
    [ -e "$child" ] || continue
    kb=$(size_kb "$child")
    if [ -z "$kb" ]; then
      # du failed — most often a root-owned/unreadable dir. Report it instead
      # of dropping it silently, so Claude can flag it as "needs sudo".
      if [ -d "$child" ] && [ ! -r "$child" ]; then
        emit "$child" 0 "$cat" ',"unreadable":true'
      fi
      continue
    fi
    [ "$kb" -ge "$MIN_KB" ] || continue
    extra=",\"last_modified\":\"$(mtime_iso "$child")\""
    case "$child" in
      "$HOME_DIR"/.*) extra="$extra$(cli_context "$child")" ;;
    esac
    case "$cat" in
      home|discovered) extra="$extra$(git_context "$child")" ;;
    esac
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
  scan_children "$HOME_DIR/Downloads" "downloads"
  scan_children "/Library/Developer" "developer_system"
  scan_children "/Library/Caches" "system_cache"
  scan_children "/Applications" "application"
  scan_children "/private/var/folders" "system_temp"
  scan_artifacts
fi

printf '\n ]\n}\n'
