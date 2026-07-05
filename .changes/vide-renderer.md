---
bump: minor
category: Features
---

Add a Vide renderer so stories written with [Vide](https://github.com/centau/vide) can be previewed in a storybook. `createVideRenderer` implements the standard `StoryRenderer` interface (`mount`/`update`/`unmount`) and is selected automatically by `createRendererForStory` whenever a story's packages expose `Vide`.
