# mac-deepclean

A Claude Code plugin: AI-native Mac disk cleanup. Scans what's big, explains it,
classifies 🟢 safe / 🟡 ask / 🔴 untouchable, cleans with consent.

**Read `docs/superpowers/specs/2026-07-08-mac-deepclean-design.md` before doing
anything — it is the approved design and carries the full project context.**

## Project state
- [x] Brainstorm + design (spec above; sections approved by user 2026-07-08)
- [x] User final review of spec
- [x] Implementation plan (docs/superpowers/plans/2026-07-08-mac-deepclean-v1.md)
- [x] scan.sh + tests
- [x] SKILL.md + references (knowledge-base.md, safety-rules.md)
- [x] commands/deepclean.md, plugin.json, marketplace.json
- [x] README showcase + publish to GitHub (repo: khankoc/mac-deepclean)
- [x] v0.1.0 released (2026-07-09; final whole-branch review: READY FOR RELEASE)
- [ ] Real-session install dry-run: `/plugin marketplace add khankoc/mac-deepclean`, `/plugin install mac-deepclean`, `/deepclean report`

## Non-negotiables
- Safety rules in the spec are the product's core. Never weaken them for convenience.
- The scanner measures; Claude decides. Don't move judgment into the script.
- Repo language: English. Conversation with the author may be in Turkish.

## Origin
Born from a live cleanup session (2026-07-08) that freed ~55 GB on the author's
Mac. Real incidents that shaped the safety rules: an unpushed-check before deleting
a repo, backing up an untracked .env, recognizing live n8n data, investigating why
colima existed before removing it.
