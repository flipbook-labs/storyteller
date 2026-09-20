---
bump: patch
category: Changes
---

Harden the renderer test suite: pin every renderer's full mount, update, and unmount lifecycle through the public `render()` entry point, add a `createRendererForStory` selection spec, cover the `transformProps` hook and props merge precedence, give Roact end-to-end coverage, and extend the same middleware-persistence coverage to the Iris renderer.