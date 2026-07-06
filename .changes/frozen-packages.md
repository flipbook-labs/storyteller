---
bump: patch
category: Fixed
---

Keep a loaded storybook or story's `packages` mutable when Charm deep-freezes its state in Studio. The `packages` hold the module exports of UI libraries like React and Fusion, which reassign their own module-level state while rendering and cannot be frozen.
