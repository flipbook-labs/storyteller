---
bump: patch
category: Internal
kind: tooling
---

List the files a Lute package of Storyteller ships in `pkg.luau`, and ship `src/.config.luau` so a vendored copy keeps its `@root` alias. The file also ships in `dist/` and the Wally package, where Roblox can read it once instances can define aliases.
