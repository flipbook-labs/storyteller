---
bump: patch
category: Fixed
---

Apply a storybook's `mapDefinition` middleware exactly once when the React renderer mounts a story, matching the Roact renderer. Control changes re-render the already-mapped story rather than re-applying the middleware, so a non-idempotent `mapDefinition` no longer stacks transformations on every update.
