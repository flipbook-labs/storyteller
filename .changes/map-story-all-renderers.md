---
bump: minor
category: Fixed
---

Apply a storybook's `mapStory` middleware in every renderer. Previously only React and Roact used it — Fusion, Vide, Iris, and manual stories ignored it entirely (flipbook-labs/flipbook#552).
