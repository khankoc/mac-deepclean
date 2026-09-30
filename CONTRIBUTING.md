# Contributing

Thanks for helping make Mac cleanup smarter and safer.

## The two rules

1. **Safety rules are the product.** A PR that makes cleanup more aggressive
   needs a strong argument; a PR that makes it stricter is almost always welcome.
2. **The scanner measures; Claude decides.** `scripts/scan.sh` must never delete,
   move, or modify anything, and must not encode judgment ("this is safe").
   CI greps it for mutating commands on every push.

## Easiest contribution: teach it something

Found a big folder `/deepclean` didn't recognize? Add a row to
`skills/deepclean/references/knowledge-base.md`:

| Path / pattern | What it is | Default tier |
|---|---|---|
| `~/Library/Caches/com.example.App` | Example's download cache; re-downloads | 🟢 |

Tier guide: 🟢 regenerable with no user cost · 🟡 regenerable but costly
(big re-download, re-render) or usage-dependent · 🔴 user data or irreplaceable.
When unsure, pick the stricter tier. Or just open a
[knowledge-base issue](../../issues/new?template=knowledge-base.yml).

## Scanner changes

- Plain bash, **3.2-compatible** (the version macOS ships). No dependencies.
- Add a test in `tests/` first; run both suites:

  ```
  bash tests/test_scan.sh && bash tests/test_scan_context.sh
  ```

- Output stays valid JSON; new fields are additive.

## Trying your changes locally

```
claude --plugin-dir .
```

then run `/deepclean report` (analysis only — deletes nothing).
