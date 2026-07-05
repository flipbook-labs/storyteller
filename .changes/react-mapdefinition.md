---
bump: patch
category: Fixed
---

Apply a storybook's `mapDefinition` middleware exactly once when the React renderer mounts a story, matching the Roact renderer. Previously every control change re-applied it to the already-mapped story, stacking transformations for non-idempotent middleware.
