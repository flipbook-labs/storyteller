---
bump: patch
category: Changes
---

Load Story modules lazily through store-owned requests: discovery never evaluates modules, the selected Story loads ahead of background batches, and consumers share one cached record per Story module and Storybook pair instead of each owning a loader. Storyteller copies evaluated inside ModuleLoader sandboxes stay inert: discovery does not start, and the shared game store is created lazily on first access instead of at require time.
