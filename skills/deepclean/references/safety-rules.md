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
