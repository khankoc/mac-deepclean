# Security Policy

mac-deepclean guides deletion of files, so a safety bug is a security bug.

## What counts

- Anything that could lead to deleting user data without explicit consent
- A path classified 🟢 that can hold irreplaceable data
- The scanner writing, moving, or deleting anything
- Claude running `sudo` instead of handing the command to the user
- Prompt-injection vectors (e.g. a crafted folder name that alters behavior)

## Reporting

Please **do not** open a public issue for these. Use GitHub's
[private vulnerability reporting](https://github.com/khankoc/mac-deepclean/security/advisories/new).
You'll get a response within a few days.

For a wrong-but-harmless classification (too strict), a normal issue is fine.
