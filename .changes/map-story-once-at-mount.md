---
bump: patch
category: Fixes
---

Apply a storybook's `mapStory` middleware once per mount in the React and Roact renderers, so control changes update the story in place instead of remounting it.
