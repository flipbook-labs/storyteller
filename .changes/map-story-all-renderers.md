---
bump: minor
category: Fixed
---

Apply a storybook's `mapStory` middleware in every renderer. Previously only the React and Roact renderers used it; Fusion, Vide, Iris, and manual stories ignored the middleware entirely (flipbook-labs/flipbook#552). For these renderers the mapped function `mapStory(story.story)` replaces the story function and is called with the story's props.
