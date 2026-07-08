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

1. 🟢 items: ask once ("Clean all safe items — {X} GB?"). On yes, before the bulk
   pass, split out any root-owned/sudo-required paths and route them to step 3
   instead — never let them fail silently inside the bulk delete. Delete remaining
   items with plain `rm -rf` per item; verify each parent still exists afterward.
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
