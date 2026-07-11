# Changelog

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
