# Changelog

## v0.1.2 — 2026-09-30

Found by running the plugin on a real, 94%-full Mac.

- Scanner: folders hidden by macOS privacy protection (TCC / Full Disk
  Access) are no longer mislabeled as root-owned "needs sudo". They're
  counted in a new top-level `tcc_protected_count` (163 on the test Mac —
  previously 163 noise rows); only home-level ones like `~/.Trash` are
  listed, with `"tcc_protected":true`.
- Scanner: genuinely unreadable folders now carry their `owner`.
- Scanner: git context adds `has_upstream`, `ahead`, `behind`, so the report
  can say "12 unpushed commits" instead of just "not synced".
- Skill: rules for TCC-protected folders (explain Full Disk Access, never
  bypass) and for ahead/no-upstream repos.
- Knowledge base: Claude desktop VM bundles, local LLM models (Ollama, Jan,
  Hugging Face, LM Studio), pnpm/Electron caches, Trash, Steam, Minecraft.
- Repo: CONTRIBUTING, SECURITY policy, issue/PR templates, marketplace
  description, star/release badges.

## v0.1.1 — 2026-07-12

- Scanner: unreadable (root-owned) directories are now reported with
  `"unreadable":true` instead of being silently dropped, so the skill can
  route them to the sudo hand-off (closes the spec's permission-denied gap).
- Scanner: `~/Downloads` scanned with its own category.
- Scanner: more default project roots (`~/code`, `~/dev`, `~/src`,
  `~/workspace`, `~/GitHub`, `~/repos`).
- Skill: Phase 2 rule for `unreadable` items.
- CI: GitHub Actions on macOS — runs both test suites, verifies the scanner
  contains no mutating commands, validates manifests.
- README: example report, comparison table, FAQ, badges.
- Added `.gitignore`, this changelog.

## v0.1.0 — 2026-07-09

- Initial release: `/deepclean` command, 4-phase skill, read-only bash
  scanner (discovery + git/orphan/artifact context), safety rules,
  knowledge base (developer / video / music / everyday), tests.
