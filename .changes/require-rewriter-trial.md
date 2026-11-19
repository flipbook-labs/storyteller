---
bump: patch
category: Internal
kind: build
---

Build `dist/` with a Luau require rewriter instead of darklua. The build no longer folds constant expressions or drops `nil` initializers, so the published modules keep the source's own formatting.
