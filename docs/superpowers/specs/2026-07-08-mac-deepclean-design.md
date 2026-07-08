# mac-deepclean — Design Spec

**Date:** 2026-07-08
**Status:** Approved sections 1–3 by user; awaiting final spec review
**Origin:** Born from a real cleanup session where this workflow freed ~55 GB on the author's Mac.

## What

A Claude Code plugin that finds what is eating a Mac's disk space, explains it,
classifies every item by safety (🟢 safe / 🟡 ask / 🔴 untouchable), and cleans
interactively — with the judgment of an LLM instead of a static deletion list.

**Positioning:** "CleanMyMac deletes from a list. This one checks if your repo is
pushed first."

**Audience:** Everyone (developers, video editors, musicians, designers, everyday
users), with extra depth on developer artifacts. Repo language: English.

## Why not existing tools

Mole (44k stars), ClearDisk, PureMac, mac-cleaner-cli all clean from fixed lists.
None can: check git push state before deleting a repo, back up an untracked .env,
investigate WHY an unknown 5 GB folder exists, or ask the user whether they still
use the iOS simulator. That reasoning is the product. The "AI-native disk cleanup"
niche among Claude Code plugins is empty.

## Architecture (Approach B: skill + bundled scanner)

The scanner script measures; Claude decides. The skill also contains the full
methodology so Claude can proceed manually if the script fails (Approach A is a
subset of B).

```
mac-deepclean/
├── .claude-plugin/
│   ├── plugin.json          # manifest: name, version, description, keywords
│   └── marketplace.json     # so users can: /plugin marketplace add khankoc/mac-deepclean
├── commands/
│   └── deepclean.md         # /deepclean — entry point, drives the 4-phase flow
├── skills/
│   └── deepclean/
│       ├── SKILL.md         # the brain: methodology, flow, classification logic
│       └── references/
│           ├── knowledge-base.md   # what things are (dev + video + music + design + everyday)
│           └── safety-rules.md     # the non-negotiables
├── scripts/
│   └── scan.sh              # discovery scanner, JSON output
├── README.md                # showcase: install, before/after story, screenshots
└── LICENSE                  # MIT
```

Install UX:
```
/plugin marketplace add khankoc/mac-deepclean
/plugin install deepclean
/deepclean
```

## The /deepclean flow (4 phases)

### Phase 1 — Discovery scan (~30s)
`scan.sh` answers "what is actually big on this disk?" without assuming categories.
It walks: home dir, hidden dot-dirs, ~/Library (Caches, Application Support,
Containers, Developer, Group Containers, Logs), /Library, /private/var,
/Applications, Downloads. Descends largest-first.

For every large item it collects **context**, not just size:
- last-used / modification date
- owning app still installed? (orphan detection — e.g. a pnpm store with no pnpm)
- if a git repo: remote configured, in sync, dirty files
- belongs to a running service? (docker, databases, sync clients)

Output: JSON list of {path, size, context…}. The fixed knowledge base is an
*accelerator for interpretation*, never the *boundary of the scan*.

### Phase 2 — Intelligent interpretation
Claude identifies each item using `knowledge-base.md` (dev caches, Xcode/simulators,
Docker; Final Cut render files, Premiere media cache; Logic/Ableton libraries;
Canva/Figma caches; Telegram/WhatsApp media; old iPhone backups; mail attachments).
For items it does NOT recognize it investigates like a human would (creation date,
what installed it, what references it) instead of guessing. Then it produces one
colorful report:
- 🟢 **Safe** — regenerable caches/artifacts, with total GB
- 🟡 **Ask** — usage-dependent (simulators, container tools, rarely used apps)
- 🔴 **Untouchable** — personal files, live data, unpushed work; shown WITH the
  reason ("building trust by explaining what we won't touch")

### Phase 3 — Consented cleanup
- 🟢 items: one bulk confirmation
- 🟡 items: one-by-one via AskUserQuestion
- sudo-requiring paths: never run by Claude — handed to the user as a ready command
- anything valuable but unbacked (e.g. untracked .env in a repo being deleted):
  backed up first, user told where

### Phase 4 — Closing report
Before/after free space, what was deleted and why, prevention tips (Xcode runtime
hygiene, `flutter clean` habits, `docker system prune`, etc.).

## Safety rules (the heart — safety-rules.md)

1. **Never touch:** user files (Documents/Desktop/Photos/Music), .env & credentials,
   data dirs of running or installed services (Docker volumes, n8n_data-style
   bind mounts), git repos that are dirty or not pushed, app settings/preferences.
2. **Evidence before deletion:** deleting a repo requires `git status` + remote
   sync check; deleting "orphaned" data requires proof the owning app is gone;
   untracked-but-valuable files get backed up first.
3. **When uncertain, ask — never assume.** That's what the 🟡 tier is for.
4. **Claude never runs sudo.** Ready-made commands are handed to the user.
5. **Every deletion is reported:** what, why, how many GB.

## Error handling
- `scan.sh` fails or is blocked → Claude falls back to manual scanning using the
  methodology in SKILL.md (Approach A subset).
- Permission-denied paths → collected and reported as "needs sudo" instead of erroring.
- Unknown macOS layout changes → unknown items flow into the "investigate" path
  by design; the plugin degrades to asking rather than deleting.

## Testing
- `scan.sh` unit-tested with bats (or plain sh assertions) against fixture dirs:
  fake node_modules, fake orphan store, fake dirty repo → correct JSON.
- Skill dry-run: /deepclean on the author's machine with a "report-only" first pass.
- Safety regression list: the scenarios from the origin session (unpushed repo,
  untracked .env, live n8n data, running docker) must all land in 🔴/🟡, never 🟢.

## Out of scope (v1)
- Windows/Linux support
- Scheduled/automatic cleaning (user runs /deepclean when they want)
- Standalone CLI distribution (Approach C — rejected)
- GUI

## Decisions log
- Language: English (discoverability)
- Audience: everyone, dev-deep
- UX: single command /deepclean
- Architecture: B (skill + scanner), containing A (pure-skill fallback)
- Name: mac-deepclean ("mac" must appear in the name — user request)
