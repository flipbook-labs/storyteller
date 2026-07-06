---
bump: minor
category: Features
---

Honor a storybook's `mapDefinition` middleware in the Fusion, Vide, and Manual renderers, matching the existing behavior in React and Roact. The definition is now transformed exactly once when a story mounts, regardless of which renderer is used.
