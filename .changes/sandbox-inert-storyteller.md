---
bump: patch
category: Fixes
---

Storyteller copies evaluated inside ModuleLoader sandboxes stay inert: discovery does not start, and the shared game store is created lazily on first access instead of at require time. Story modules whose dependency graphs include Storyteller no longer spawn per-sandbox discovery machinery, which crashed React stories in Studio.
