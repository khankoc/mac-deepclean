# mac-deepclean v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a working Claude Code plugin (`/deepclean`) that scans a Mac for space hogs, classifies them 🟢/🟡/🔴 with LLM judgment, and cleans with consent.

**Architecture:** A bash scanner (`scripts/scan.sh`) measures and gathers context (sizes, git state, orphaned tools) and emits JSON; the skill (`skills/deepclean/SKILL.md` + references) tells Claude how to interpret, classify, ask, and delete safely. The scanner never deletes anything. The skill contains the full manual methodology as fallback if the script fails.

**Tech Stack:** bash 3.2 (macOS stock — no associative arrays, no bash-4isms), `du`/`stat`/`git`/`find`, plain-sh tests, Claude Code plugin format (plugin.json + marketplace.json + commands/ + skills/).

## Global Constraints

- Repo language: English (all shipped files; spec: "Repo language: English").
- Plugin name: `mac-deepclean`; command: `/deepclean`; license: MIT.
- Scanner measures only — **no `rm`, no writes outside stdout** in scan.sh.
- Claude never runs sudo — sudo paths are handed to the user as ready commands.
- Safety rules in `docs/superpowers/specs/2026-07-08-mac-deepclean-design.md` are non-negotiable; the regression scenarios there (unpushed repo, untracked .env, live service data, running docker) must classify 🔴/🟡, never 🟢.
- Target macOS: current versions; script must run on stock `/bin/bash` 3.2.

---

### Task 1: Plugin manifests

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: plugin name `mac-deepclean` (namespaces the command as `/deepclean` via commands/), marketplace installable with `/plugin marketplace add khankoc/mac-deepclean`.

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "mac-deepclean",
  "version": "0.1.0",
  "description": "AI-native Mac disk cleanup. Finds what's big, explains it, classifies safe/ask/untouchable, and cleans with your consent — it checks whether your repo is pushed before it would ever touch it.",
  "author": { "name": "Kaan Koc" },
  "homepage": "https://github.com/khankoc/mac-deepclean",
  "repository": "https://github.com/khankoc/mac-deepclean",
  "license": "MIT",
  "keywords": ["mac", "macos", "disk", "cleanup", "storage", "cache", "space"]
}
```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "mac-deepclean",
  "owner": { "name": "Kaan Koc" },
  "plugins": [
    {
      "name": "mac-deepclean",
      "source": "./",
      "description": "AI-native Mac disk cleanup for Claude Code. /deepclean scans, explains, and cleans with judgment."
    }
  ]
}
```

- [ ] **Step 3: Validate both files are legal JSON**

Run: `python3 -m json.tool .claude-plugin/plugin.json && python3 -m json.tool .claude-plugin/marketplace.json`
Expected: both pretty-print, exit 0.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin
git commit -m "feat: plugin and marketplace manifests"
```

---

### Task 2: Scanner core — discovery + JSON output

**Files:**
- Create: `scripts/scan.sh`
- Test: `tests/test_scan.sh`

**Interfaces:**
- Produces: `scripts/scan.sh` executable. Env vars: `DEEPCLEAN_MIN_MB` (threshold, default 100), `DEEPCLEAN_ROOTS` (colon-separated roots overriding the default set — used by tests), `DEEPCLEAN_HOME` (home override), `DEEPCLEAN_CODE_DIRS` (colon-separated project roots). Output JSON shape:
  `{"scanned_at": "...", "min_mb": N, "items": [{"path": "...", "size_kb": N, "category": "...", "last_modified": "YYYY-MM-DD", ...optional context fields}]}`
- Categories emitted in this task: `discovered` (when DEEPCLEAN_ROOTS set), `home`, `user_cache`, `app_support`, `container`, `developer`, `developer_system`, `logs`, `system_cache`, `application`, `system_temp`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_scan.sh`:

```bash
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
```

Make it executable: `chmod +x tests/test_scan.sh`

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_scan.sh`
Expected: FAIL (scripts/scan.sh does not exist yet; the OUT= line errors and assertions fail).

- [ ] **Step 3: Write the scanner core**

Create `scripts/scan.sh`:

```bash
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
```

Make it executable: `chmod +x scripts/scan.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_scan.sh`
Expected: `PASS: scanner core`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/scan.sh tests/test_scan.sh
git commit -m "feat: scanner core — threshold discovery with JSON output"
```

---

### Task 3: Scanner context — git state, orphaned CLI tools, project artifacts

**Files:**
- Modify: `scripts/scan.sh`
- Test: `tests/test_scan_context.sh`

**Interfaces:**
- Consumes: `emit`, `size_kb`, `mtime_iso`, `scan_children`, `json_escape` from Task 2 (exact names above).
- Produces: additional JSON context fields:
  - on git repos/artifacts: `"git":{"has_remote":bool,"dirty_files":N,"synced_with_remote":bool}`
  - on hidden tool dirs (`~/.<tool>`): `"cli_installed":bool`
  - new category `project_artifact` for node_modules/.next/dist/build/.dart_tool/venv/.venv/target/out dirs found under `DEEPCLEAN_CODE_DIRS` (default `$HOME/Documents:$HOME/Desktop:$HOME/Developer:$HOME/Projects`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_scan_context.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_scan_context.sh`
Expected: FAIL — `node_modules git context wrong: missing` (no artifact scanning yet) and `orphan cli_installed flag wrong: bad`.

- [ ] **Step 3: Add context functions and artifact scan to `scripts/scan.sh`**

Insert after `mtime_iso()`:

```bash
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
  local roots="${DEEPCLEAN_CODE_DIRS:-$HOME_DIR/Documents:$HOME_DIR/Desktop:$HOME_DIR/Developer:$HOME_DIR/Projects}"
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
```

Then wire them in:
1. In `scan_children`, after `extra=",\"last_modified\":..."` add hidden-tool detection:

```bash
    case "$child" in
      "$HOME_DIR"/.*) extra="$extra$(cli_context "$child")" ;;
    esac
    case "$cat" in
      home|discovered) extra="$extra$(git_context "$child")" ;;
    esac
```

(`git_context` walks up, so it emits nothing for non-repos — safe to call.)

2. In the default-roots branch of the main body (NOT the DEEPCLEAN_ROOTS branch), add as last line before `printf '\n ]\n}\n'`:

```bash
  scan_artifacts
```

Wait — `scan_artifacts` must run when `DEEPCLEAN_CODE_DIRS` is set even if `DEEPCLEAN_ROOTS` is unset (the test sets CODE_DIRS + HOME, no ROOTS). Put `scan_artifacts` in the `else` branch (default scan). The test exercises the default branch via `DEEPCLEAN_HOME`, so this works.

- [ ] **Step 4: Run both tests to verify pass and no regression**

Run: `bash tests/test_scan.sh && bash tests/test_scan_context.sh`
Expected: `PASS: scanner core` then `PASS: scanner context`, exit 0.

Note: `test_scan.sh` uses `DEEPCLEAN_ROOTS`, which skips `scan_artifacts` — but `scan_children` now calls `git_context` for `discovered` items; fixture dirs are not repos, so output is unchanged. If it fails, the regression is real: fix, don't loosen the test.

- [ ] **Step 5: Commit**

```bash
git add scripts/scan.sh tests/test_scan_context.sh
git commit -m "feat: scanner context — git state, orphaned CLIs, project artifacts"
```

---

### Task 4: Reference docs — safety-rules.md and knowledge-base.md

**Files:**
- Create: `skills/deepclean/references/safety-rules.md`
- Create: `skills/deepclean/references/knowledge-base.md`

**Interfaces:**
- Produces: two markdown references loaded by SKILL.md (Task 5) via relative paths `references/safety-rules.md` and `references/knowledge-base.md`.

- [ ] **Step 1: Write `skills/deepclean/references/safety-rules.md`**

```markdown
# Safety Rules — Non-Negotiable

These rules exist because deleting the wrong thing destroys someone's work.
When any rule conflicts with saving disk space, the rule wins.

## 1. Never touch

- User content: Documents, Desktop, Downloads contents, Photos, Music, Movies,
  iCloud Drive. Report them, never delete them (offer the user to review manually).
- Secrets and config: `.env*`, `credentials*`, `*.pem`, `*.key`, keychains,
  `~/.ssh`, `~/.aws`, `~/.config`, app preferences/settings.
- Live service data: Docker volumes and `com.docker.docker` when Docker is used,
  database data dirs, anything bind-mounted by a compose file (e.g. an `n8n_data/`
  folder next to a docker-compose.yml), sync-client state (OneDrive/Dropbox/iCloud).
- Git repos that are dirty, unpushed, or have no remote. Their build artifacts
  (node_modules, build/) may still be 🟢 — the *repo itself* is 🔴.
- Anything you cannot identify after investigating. Unknown ≠ deletable.

## 2. Evidence before deletion

- Deleting a whole repo/folder the user asked about: run `git status --porcelain`
  and verify remote sync yourself — do not trust memory or assumptions.
- Deleting "orphaned" tool data (e.g. a package-manager store): verify the owning
  CLI/app is actually absent (`command -v`, check /Applications), not just unused.
- Before deleting a folder that contains ANY untracked-but-valuable file
  (e.g. `.env` in a repo): copy it to a backup location first and tell the user where.

## 3. When uncertain, ask — never assume

Usage-dependent items (simulators, container tools, SDKs, media libraries,
rarely-used apps) are 🟡: one AskUserQuestion each, with the size, what it is,
and the exact cost of deletion ("re-download ~8 GB when needed").

## 4. Claude never runs sudo

Root-owned paths (e.g. /Library/Developer/CoreSimulator/Caches, /Applications
apps owned by root) are handed to the user as a ready-made command they run
themselves. Explain what it does in one line.

## 5. Every deletion is reported

What was deleted, why it was safe, how many GB. If something was backed up
first, say where. If something failed, say so plainly.

## Regression scenarios (must always hold)

| Scenario | Required classification |
|---|---|
| Repo with no remote / unpushed commits / dirty files | 🔴 repo (artifacts inside may be 🟢) |
| Untracked `.env` inside anything being deleted | back up first, then proceed |
| `n8n_data`-style live service dir | 🔴 |
| Docker data while user says they use Docker | 🔴 |
| Package-manager store whose CLI is still installed | 🟡 at most |
```

- [ ] **Step 2: Write `skills/deepclean/references/knowledge-base.md`**

```markdown
# Knowledge Base — What Things Are

Interpretation accelerator. The scan is NOT limited to this list; anything big
and unrecognized goes through the investigation flow in SKILL.md instead.
Tiers here are defaults — context (git state, running services, user answers)
can move an item to a stricter tier, never to a looser one.

Sizes marked "regen" mean: deleting costs only a re-download/rebuild.

## Developer

| Path / pattern | What it is | Default tier |
|---|---|---|
| `**/node_modules` | npm packages; `npm install` regenerates | 🟢 (repo must not be 🔴-blocked for full-repo deletes; artifact itself regen) |
| `**/.next`, `**/dist`, `**/build`, `**/out`, `**/target` | build output; rebuilt on demand | 🟢 |
| `**/.dart_tool`, Flutter `build/` | Flutter/Dart build cache; `flutter clean` territory | 🟢 |
| `**/venv`, `**/.venv` | Python virtualenv; `pip install -r requirements.txt` regenerates | 🟢 |
| `~/.npm/_cacache`, `~/.npm/_npx` | npm download cache | 🟢 |
| `~/.gradle/caches`, `~/.gradle/wrapper` | Android/Gradle deps; re-downloaded on next build | 🟢 |
| `~/.pub-cache` | Flutter packages; `pub get` regenerates | 🟢 |
| `~/.cache/uv`, `~/Library/Caches/pip` | Python package caches | 🟢 |
| `~/Library/Caches/Homebrew` | brew download cache (`brew cleanup`) | 🟢 |
| `~/Library/Caches/CocoaPods` | iOS dependency cache | 🟢 |
| `~/Library/Developer/Xcode/DerivedData` | Xcode intermediate builds | 🟢 |
| `~/Library/Developer/CoreSimulator/Devices` | simulator devices with installed apps | 🟡 (user may be mid-testing) |
| `/Library/Developer/CoreSimulator/Volumes` | iOS runtime images (~8 GB each); re-downloadable | 🟡 + old versions 🟢 |
| `/Library/Developer/CoreSimulator/Caches` | simulator dyld caches; regenerate on boot | 🟢 (sudo — hand to user) |
| `~/Library/Android/sdk` | Android SDK/NDK; needed for Android builds | 🟡 |
| `~/Library/Containers/com.docker.docker` | Docker Desktop VM disk (images+volumes) | 🔴 if used; 🟡 if not running/stale |
| `~/.colima` | Colima (Docker alternative) VM disk | 🟡 — check active docker context |
| `~/.dartServer` | Dart analysis cache | 🟢 |
| `~/Library/Caches/ms-playwright*` | Playwright browser binaries | 🟢 |
| `*.xcarchive`, `~/Library/Developer/Xcode/Archives` | app archives — may hold unreleased builds | 🟡 |
| `~/Library/Developer/Xcode/iOS DeviceSupport` | per-iOS-version debug symbols; regen on device connect | 🟢 |

## Video / Photo

| Path / pattern | What it is | Default tier |
|---|---|---|
| Final Cut `*.fcpbundle/**/Render Files` | render cache; FCP re-renders | 🟢 |
| `~/Movies/**/Optimized Media`, `Proxy Media` | FCP optimized/proxy copies of originals | 🟡 (large re-encode time) |
| Premiere `~/Documents/Adobe/Premiere Pro/**/Media Cache*` | media cache; regenerates | 🟢 |
| After Effects `Disk Cache` | preview cache | 🟢 |
| `~/Pictures/Photos Library.photoslibrary` | THE photo library | 🔴 |
| Lightroom `*.lrcat-data`, previews `*.lrdata` | previews regen; catalog itself 🔴 | previews 🟢, catalog 🔴 |

## Music / Audio

| Path / pattern | What it is | Default tier |
|---|---|---|
| Logic `~/Music/Audio Music Apps`, sampler instruments | user instruments/patches | 🔴 |
| `/Library/Application Support/GarageBand`, `Logic/*.pkg` sound libraries | Apple loops/sounds; re-downloadable in-app | 🟡 |
| Ableton `~/Music/Ableton/**/Cache` | decoding/analysis cache | 🟢 |
| `~/Music/iTunes`, `~/Music/Music` | THE music library | 🔴 |

## Everyday

| Path / pattern | What it is | Default tier |
|---|---|---|
| `~/Library/Caches/ru.keepcoder.Telegram` | Telegram media cache; re-downloads from cloud | 🟢 |
| WhatsApp `~/Library/Group Containers/*.WhatsApp*/Media` | may be the ONLY copy of received media | 🟡 |
| `~/Library/Caches/Google`, browser caches | web caches | 🟢 |
| `~/Library/Application Support/MobileSync/Backup` | old iPhone/iPad backups | 🟡 (check device + date) |
| Mail `~/Library/Mail` | local mail store | 🔴 (offer Mail.app attachment cleanup instead) |
| `~/Library/Application Support/com.apple.wallpaper` | aerial wallpaper videos; switch to static to shrink | 🟡 |
| `*.ShipIt`, `*-updater` caches | app auto-update leftovers | 🟢 |
| `~/Downloads` old `.dmg`/`.zip` installers | installers already installed | 🟡 (list, let user pick) |
| `/private/var/folders` | macOS-managed temp; do NOT rm blindly | 🔴 (reboot shrinks it) |

## Orphan pattern (any category)

Data dir whose owning app/CLI is gone (scanner: `cli_installed:false`, or no
matching app in /Applications) → verify absence, then 🟢. Examples seen in the
wild: `~/Library/pnpm` with no pnpm, `~/.codex` with no codex.
```

- [ ] **Step 3: Sanity-check both files render (no broken tables)**

Run: `grep -c '^|' skills/deepclean/references/knowledge-base.md`
Expected: a number > 40 (all table rows present).

- [ ] **Step 4: Commit**

```bash
git add skills/deepclean/references
git commit -m "feat: safety rules and knowledge base references"
```

---

### Task 5: The skill — SKILL.md

**Files:**
- Create: `skills/deepclean/SKILL.md`

**Interfaces:**
- Consumes: `${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh` (Tasks 2–3 JSON shape), `references/safety-rules.md`, `references/knowledge-base.md` (Task 4).
- Produces: skill named `deepclean`, auto-triggerable on disk-space complaints, driven by `/deepclean` command (Task 6).

- [ ] **Step 1: Write `skills/deepclean/SKILL.md`**

```markdown
---
name: deepclean
description: Use when the user wants to free disk space on their Mac, asks why their disk is full, mentions storage problems, System Data being huge, or runs /deepclean. Scans intelligently, explains findings, classifies by safety, cleans only with consent.
---

# deepclean — AI-native Mac disk cleanup

You are about to clean someone's computer. Read `references/safety-rules.md`
first and treat it as law. Read `references/knowledge-base.md` to identify items.

The scanner MEASURES; you DECIDE. Never let the script's output substitute for
your judgment, and never delete anything the user hasn't consented to.

## Phase 1 — Discovery scan

Run: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh"` (add `DEEPCLEAN_MIN_MB=50`
for thorough mode if the user asks). Parse the JSON. Also capture
`df -h /System/Volumes/Data` for the before/after story.

If the script fails or is blocked: fall back to manual scanning with `du -sh`
over: home dir + hidden dirs, ~/Library/{Caches,Application Support,Containers,
Group Containers,Developer,Logs}, /Library/Developer, /Applications,
/private/var/folders, and project-artifact `find` for node_modules/.next/build/
venv/target. Same methodology, slower.

## Phase 2 — Intelligent interpretation

For each significant item:
1. Identify via knowledge-base. Respect its tier defaults.
2. UNKNOWN item? Investigate before classifying: creation/modification date,
   owning app installed (`ls /Applications`, `command -v`), what references it
   (config files, launchd plists), whether a service is running (`pgrep`).
   Still unknown → 🔴 with "unknown — investigate manually".
3. Apply context overrides (always toward stricter): git dirty/unpushed → 🔴;
   `cli_installed:false` verified → orphan 🟢; recently used 🟡 stays 🟡.

Then present ONE report (before any deletion):

    ## 💾 Disk Report — {free} free of {total}
    ### 🟢 Safe to clean — {X} GB total
    | Item | Size | Why safe |
    ### 🟡 Your call — up to {Y} GB
    | Item | Size | Question |
    ### 🔴 Not touching — {Z} GB
    | Item | Size | Why protected |

The 🔴 section is mandatory — showing what you WON'T touch builds trust.

## Phase 3 — Consented cleanup

1. 🟢 items: ask once ("Clean all safe items — {X} GB?"). On yes, delete with
   plain `rm -rf` per item; verify each parent still exists afterward.
2. 🟡 items: one AskUserQuestion each (or grouped multiSelect when homogeneous),
   stating the size and the exact cost of deletion.
3. sudo-needed paths: print a single ready command for the user; never run it.
4. Back up any untracked-but-valuable file BEFORE its parent is deleted; tell
   the user the backup path.

## Phase 4 — Closing report

`df -h` again. Report: GB freed, what was deleted (grouped), what was skipped
and why, backups made, and prevention tips relevant to what you found (e.g.
Xcode runtime hygiene, `flutter clean` habit, `docker system prune`, static
wallpaper). Offer to repeat in a few months.
```

- [ ] **Step 2: Verify frontmatter parses (YAML between --- markers)**

Run: `python3 -c "
import re
t=open('skills/deepclean/SKILL.md').read()
m=re.match(r'^---\n(.*?)\n---\n', t, re.S)
assert m, 'no frontmatter'
assert 'name: deepclean' in m.group(1)
print('OK')
"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add skills/deepclean/SKILL.md
git commit -m "feat: deepclean skill — 4-phase methodology with manual fallback"
```

---

### Task 6: The command — /deepclean

**Files:**
- Create: `commands/deepclean.md`

**Interfaces:**
- Consumes: skill `deepclean` (Task 5).
- Produces: `/deepclean` slash command (namespaced `/mac-deepclean:deepclean`, exposed as `/deepclean` when unambiguous).

- [ ] **Step 1: Write `commands/deepclean.md`**

```markdown
---
description: Scan this Mac for wasted disk space, explain what's found, and clean it interactively and safely.
---

Free up disk space on this Mac.

Use the `deepclean` skill in this plugin and follow its four phases exactly:
scan with the bundled scanner, present the full 🟢/🟡/🔴 report BEFORE deleting
anything, clean only with the user's consent, and finish with a before/after
report. The safety rules in the skill's references are non-negotiable.

$ARGUMENTS may contain modifiers: "thorough" (scan with DEEPCLEAN_MIN_MB=50),
"report" or "dry run" (Phases 1–2 only, no cleanup).
```

- [ ] **Step 2: Verify file structure is complete for a valid plugin**

Run: `ls .claude-plugin/plugin.json commands/deepclean.md skills/deepclean/SKILL.md skills/deepclean/references/safety-rules.md skills/deepclean/references/knowledge-base.md scripts/scan.sh`
Expected: all six paths print, exit 0.

- [ ] **Step 3: Commit**

```bash
git add commands/deepclean.md
git commit -m "feat: /deepclean command entry point"
```

---

### Task 7: README showcase

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: install flow from Task 1 manifests.
- Produces: the repo's landing page.

- [ ] **Step 1: Write `README.md`**

```markdown
# mac-deepclean 🧹

**AI-native disk cleanup for your Mac, inside [Claude Code](https://claude.com/claude-code).**

> CleanMyMac deletes from a list. This one checks if your repo is pushed first.

Static cleanup tools can't tell whether that 5 GB folder is a regenerable cache
or the only copy of your unpushed work. `/deepclean` can — because an LLM does
the judging, not a hardcoded list.

## What it does

1. **Scans** everything big on your disk (~30s) — dev caches, video render
   files, music libraries, app leftovers, orphaned data — and gathers context:
   last use, git push state, whether the owning app still exists.
2. **Explains** every finding in one colorful report:
   - 🟢 **Safe** — regenerable caches (node_modules, DerivedData, npm/gradle…)
   - 🟡 **Your call** — usage-dependent (iOS simulators, Docker, old backups)
   - 🔴 **Not touching** — your files, unpushed repos, live service data
3. **Cleans with consent** — 🟢 in one confirmation, 🟡 one question each,
   sudo commands handed to you, never run for you.
4. **Reports** before/after and teaches you how to keep it clean.

## Install

    /plugin marketplace add khankoc/mac-deepclean
    /plugin install mac-deepclean

Then just run:

    /deepclean

Modifiers: `/deepclean thorough` (lower size threshold), `/deepclean report`
(analysis only, deletes nothing).

## Safety model

- The bundled scanner only **measures** — it contains zero delete commands.
- Deleting a repo requires proof it's pushed and clean. Untracked valuables
  (like a `.env`) are backed up first.
- Unknown ≠ deletable: unrecognized items get investigated, not guessed at.
- Claude never runs sudo on your machine.

Born from a real session that freed **~55 GB** — including the moment it
almost mattered: a repo about to be deleted contained an untracked `.env`,
which got backed up first. That reflex is now a rule in this plugin.

## Requirements

macOS, Claude Code with plugin support. No dependencies — the scanner is
plain bash.

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README showcase"
```

---

### Task 8: End-to-end verification and release

**Files:**
- Modify: none (verification + tag)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Run the full test suite**

Run: `bash tests/test_scan.sh && bash tests/test_scan_context.sh`
Expected: both PASS.

- [ ] **Step 2: Real-machine smoke test of the scanner**

Run: `bash scripts/scan.sh | python3 -m json.tool | head -40 && bash scripts/scan.sh | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['items']),'items')"`
Expected: valid JSON, plausible items from this Mac (>5 items), no stderr noise other than permission-denied suppression.

- [ ] **Step 3: Install the plugin locally and dry-run**

In a Claude Code session: `/plugin marketplace add /Users/admin/Documents/GitHub/mac-deepclean` then `/plugin install mac-deepclean`, restart session, run `/deepclean report`.
Expected: Phases 1–2 execute; report shows 🟢/🟡/🔴 sections including a populated 🔴 section; nothing is deleted.
Verify safety regressions manually against the report: any dirty/unpushed repo on disk appears 🔴/absent from 🟢; Docker data not in 🟢.

- [ ] **Step 4: Push and tag v0.1.0**

```bash
git push origin main
git tag v0.1.0 && git push origin v0.1.0
```

- [ ] **Step 5: Update project CLAUDE.md checkboxes**

Mark implementation items done in `CLAUDE.md`'s "Project state" list, commit:

```bash
git add CLAUDE.md
git commit -m "docs: mark v1 implementation complete" && git push
```
