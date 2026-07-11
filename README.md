# mac-deepclean 🧹

**AI-native disk cleanup for your Mac, inside [Claude Code](https://claude.com/claude-code).**

[![tests](https://github.com/khankoc/mac-deepclean/actions/workflows/test.yml/badge.svg)](https://github.com/khankoc/mac-deepclean/actions/workflows/test.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![no dependencies](https://img.shields.io/badge/dependencies-none-brightgreen.svg)

> CleanMyMac deletes from a list. This one checks if your repo is pushed first.

Static cleanup tools can't tell whether that 5 GB folder is a regenerable cache
or the only copy of your unpushed work. `/deepclean` can — because an LLM does
the judging, not a hardcoded list.

## Install

```
/plugin marketplace add khankoc/mac-deepclean
/plugin install mac-deepclean
```

Then just run:

```
/deepclean
```

Modifiers: `/deepclean thorough` (lower size threshold), `/deepclean report`
(analysis only, deletes nothing).

## What a run looks like

```
## 💾 Disk Report — 63 GB free of 245 GB

### 🟢 Safe to clean — 27.4 GB total
| Item                                  | Size    | Why safe                                  |
| ~/.gradle/caches                      | 9.3 GB  | Android deps — re-downloaded on next build |
| ~/.npm/_cacache                       | 5.4 GB  | npm download cache                         |
| lojistik-site/.next + node_modules    | 10.9 GB | build output — repo is pushed & clean ✓    |
| ~/Library/Caches/ms-playwright        | 1.1 GB  | browser binaries — re-downloadable         |

### 🟡 Your call — up to 17 GB
| Item                                  | Size    | Question                                   |
| iOS Simulator runtime + device        | 26 GB   | Still testing on the simulator?            |
| ~/.colima                             | 5.4 GB  | Docker context points at Docker Desktop —  |
|                                       |         | colima hasn't run since April. Remove it?  |

### 🔴 Not touching — and why
| Item                                  | Size    | Why protected                              |
| ~/Documents, ~/Desktop                | 3.7 GB  | your files                                 |
| n8nkoc/n8n_data                       | 0.5 GB  | live service data (bind-mounted volume)    |
| oldproject/                           | 1.8 GB  | repo has NO remote — deleting = data loss  |
```

That last row is the whole point: a static tool would have "cleaned" it.

## What it does

1. **Scans** everything big on your disk (~30s) — dev caches, video render
   files, music libraries, app leftovers, orphaned data — and gathers context:
   last use, git push state, whether the owning app still exists.
2. **Explains** every finding in one report, classified 🟢 safe / 🟡 ask / 🔴 protected.
   The 🔴 section is mandatory: you see what it *won't* touch, and why.
3. **Cleans with consent** — 🟢 in one confirmation, 🟡 one question each,
   sudo commands handed to you, never run for you.
4. **Reports** before/after and teaches you how to keep it clean.

## How it's different

|                                      | mac-deepclean | CleanMyMac / Mole / static cleaners |
|--------------------------------------|:---:|:---:|
| Checks git push state before touching a repo | ✅ | ❌ |
| Backs up untracked `.env` before a delete    | ✅ | ❌ |
| Investigates unknown folders (when installed? owning app gone?) | ✅ | ❌ |
| Recognizes live service data (Docker volumes, bind mounts) | ✅ | ❌ |
| Asks *you* about usage-dependent items       | ✅ | ❌ |
| Works without an LLM                         | ❌ | ✅ |

Great standalone tools exist ([Mole](https://github.com/tw93/mole),
[Pearcleaner](https://github.com/alienator88/Pearcleaner)) — this plugin's niche
is the judgment layer they can't have.

## Safety model

- The bundled scanner only **measures** — it contains zero delete commands
  (CI enforces this with a grep on every push).
- Deleting a repo requires proof it's pushed and clean. Untracked valuables
  (like a `.env`) are backed up first.
- Unknown ≠ deletable: unrecognized items get investigated, not guessed at.
- Claude never runs sudo on your machine — root-owned paths are handed to you
  as a ready command.

Born from a real session that freed **~55 GB** — including the moment it
almost mattered: a repo about to be deleted contained an untracked `.env`,
which got backed up first. That reflex is now a rule in this plugin.

## FAQ

**Is it safe to let an LLM delete files?**
The LLM never bulk-deletes on its own judgment alone: the safety rules are a
hard allowlist/denylist layer, every delete is shown to you first, and the 🔴
tier (your files, unpushed work, live data) is never deletable at all.

**Does it work for non-developers?**
Yes — it also knows Final Cut render files, Logic sound libraries, Telegram
media caches, old iPhone backups, orphaned app data. The developer stuff is
just where it goes deepest.

**Why is my "System Data" huge?**
Usually developer tooling (simulators, SDKs, container VMs). Run
`/deepclean report` and it will show you exactly what's inside — explained.

## Requirements

macOS, Claude Code with plugin support. No dependencies — the scanner is
plain bash (3.2-compatible, ships with every Mac).

## License

MIT — if this saved you some gigabytes, a ⭐ helps others find it.
