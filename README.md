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
