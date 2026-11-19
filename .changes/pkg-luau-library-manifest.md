---
bump: patch
category: Internal
kind: tooling
---

List the files a Lute package of Storyteller ships in `pkg.luau`, and ship `src/.config.luau` so a vendored copy keeps its `@root` alias. Rojo and the `dist/` build leave that file out.
