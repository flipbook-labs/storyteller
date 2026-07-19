---
bump: patch
category: Changes
---

Load Story modules lazily through store-owned requests: discovery never evaluates modules, the selected Story loads ahead of background batches, and consumers share one cached record per Story module and Storybook pair instead of each owning a loader.
