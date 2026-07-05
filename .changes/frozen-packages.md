---
bump: patch
category: Fixed
---

Stop Charm's deep-freeze from reaching the module exports in a loaded storybook or story's `packages` (storyteller#100). UI libraries mutate their module-level state while rendering, so freezing them broke story rendering in Studio.
