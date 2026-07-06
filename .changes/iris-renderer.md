---
bump: minor
category: Features
---

Add an Iris renderer so stories written with [Iris](https://github.com/SirMallard/Iris) can be previewed in a storybook. Iris is an immediate-mode global singleton, so the renderer initializes it lazily, re-points it at each newly mounted story, and freezes it on unmount.