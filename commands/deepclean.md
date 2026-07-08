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
