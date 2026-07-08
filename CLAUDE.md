# mac-deepclean

A Claude Code plugin: AI-native Mac disk cleanup. Scans what's big, explains it,
classifies 🟢 safe / 🟡 ask / 🔴 untouchable, cleans with consent.

**Read `docs/superpowers/specs/2026-07-08-mac-deepclean-design.md` before doing
anything — it is the approved design and carries the full project context.**

## Project state
- [x] Brainstorm + design (spec above; sections approved by user 2026-07-08)
- [ ] User final review of spec
- [ ] Implementation plan (superpowers:writing-plans)
- [ ] scan.sh + tests
- [ ] SKILL.md + references (knowledge-base.md, safety-rules.md)
- [ ] commands/deepclean.md, plugin.json, marketplace.json
- [ ] README showcase + publish to GitHub (repo: khankoc/mac-deepclean)

## Non-negotiables
- Safety rules in the spec are the product's core. Never weaken them for convenience.
- The scanner measures; Claude decides. Don't move judgment into the script.
- Repo language: English. Conversation with the author may be in Turkish.

## Origin
Born from a live cleanup session (2026-07-08) that freed ~55 GB on the author's
Mac. Real incidents that shaped the safety rules: an unpushed-check before deleting
a repo, backing up an untracked .env, recognizing live n8n data, investigating why
colima existed before removing it.
