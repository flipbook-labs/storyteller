---
bump: patch
category: Changes
---

CI and release workflows now source their secrets from the shared Flipbook 1Password vault at run time via `load-secrets-action` (the Roblox Open Cloud test key and the release app's private key), rather than from repo-level GitHub Actions secrets. No effect on the published package.
