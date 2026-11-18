---
bump: patch
category: Fixes
---

`loadStorybookModule` no longer writes to the table a storybook module returns, so loaders with a require cache don't stack `group` prefixes across loads.
