---
bump: patch
category: Fixes
---

Apply a storybook's `mapStory` middleware once per mount in the React and Roact renderers, so control changes update the story in place instead of remounting it. The mapped component no longer receives the story element as `children` (except for stories that are themselves elements), so a `mapStory` that passes its props on to the story doesn't hand the story a second copy of itself.
