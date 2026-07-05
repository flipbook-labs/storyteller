---
bump: patch
category: Fixed
---

Apply a storybook's `mapDefinition` middleware exactly once when the React renderer mounts a story. Previously every control change re-applied it to the already-mapped story, so a non-idempotent `mapDefinition` (one that wraps or decorates the story) would stack another transformation on each update. The Roact renderer already behaved correctly; the two now match.
