---
bump: patch
category: Changes
---

Document the `colorMode` and `themeName` story props that hosts supply, and deprecate `theme` in favor of `colorMode`. Storyteller sets no default for either new prop, so they are `nil` unless the host supplies them. `theme` still defaults to `"Dark"`.
