---
bump: patch
category: Changes
---

Harden the renderer test suite: pin every renderer's full mount, update, and unmount lifecycle through `render()`, add the missing `createRendererForStory` selection spec, cover the `transformProps` hook and props merge precedence, and give Roact end-to-end coverage. Also fix the two Fusion unmount tests that were silently exercising the Manual renderer.