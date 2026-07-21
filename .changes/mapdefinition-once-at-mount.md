---
bump: patch
category: Fixes
---

Apply a storybook's `mapDefinition` middleware exactly once when the React renderer mounts a story, matching the other renderers. Control changes now re-render the already-mapped story rather than re-applying the middleware, so a non-idempotent `mapDefinition` no longer stacks transformations on every update.
