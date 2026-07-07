---
bump: patch
category: Changes
---

Adopt Archivist for logging. StorytellerStore now logs its lifecycle (start/stop) and storybook loading (loaded, failed, unloaded, reloaded) through a structured logger, controllable via `LOG_LEVEL` / `_G.LOG_LEVEL`. Repo scripts report status through the same logger.
