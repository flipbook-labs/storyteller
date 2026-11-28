# Changelog

All notable changes to this project will be documented in this file.

## v1.16.0

Changes 1 · Internal 2

### Changes

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Upgrade to ModuleLoader 1.0, so a loader passed to Storyteller's load functions must come from `createModuleLoader`. ([#245](https://github.com/flipbook-labs/storyteller/pull/245))

<details>
<summary>Details</summary>

`loadStorybookModule`, `loadStoryModule` and `loadStoriesFromModule` take an optional loader, and Storyteller now calls it with ModuleLoader 1.0's functions, such as `loader.require(module)`. A loader made with `ModuleLoader.new()` from 0.13 no longer works there. Make one with `ModuleLoader.createModuleLoader()` instead.

When a Storybook or story module fails to load, the error from `loadStorybookModule` or `loadStoryModule` and a story record's `problem` still include the stack after the message. ModuleLoader 1.0 raises the message on its own, so Storyteller now reads the stack from `getLastError`.

</details>

### Internal

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop" /></picture> Record each Wally publish as a deployment to the `wally` environment. ([#246](https://github.com/flipbook-labs/storyteller/pull/246))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop" /></picture> Overlay Storyteller into Flipbook with flipbook-batteries, which rewrites every link to it and adds links for new dependencies. ([#248](https://github.com/flipbook-labs/storyteller/pull/248))

## v1.15.0

Features 1 · Changes 1 · Fixes 1 · Internal 2

### Features

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Keep a Story's last working version loaded when an edit stops it loading, and report the error in the record's new `problem` field. ([#237](https://github.com/flipbook-labs/storyteller/pull/237))

<details>
<summary>Details</summary>

A record's `problem`, on Loaded and Unavailable records alike, starts with the error's message, without a "Failed to load story" prefix. ModuleLoader's traceback follows on the next lines.

</details>

### Changes

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Reload a Story once typing stops for 300 ms when its module or a dependency is open in the script editor, instead of on every keystroke. ([#236](https://github.com/flipbook-labs/storyteller/pull/236))

### Fixes

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-react-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-react-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-react-light.png" alt="React" height="18" align="texttop" /></picture> Keep `StoryContainer` mounted when a Story's teardown throws, and log the error instead of passing it to the host. ([#235](https://github.com/flipbook-labs/storyteller/pull/235))

### Internal

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Add regression tests for how Rojo syncs, Studio edits, and Storybooks reload a Story. ([#240](https://github.com/flipbook-labs/storyteller/pull/240))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Run a Storybook module that throws once per story load, not twice. ([#244](https://github.com/flipbook-labs/storyteller/pull/244))

## v1.14.0

Features 1 · Changes 4 · Fixes 1 · Internal 3

### Features

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Add `requestStoryModule` and `getStoryModuleRecord` for loading a module's Stories and watching them for changes. ([#145](https://github.com/flipbook-labs/storyteller/pull/145))

### Changes

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Track every Story loaded from a module and select a Story by its ID in `useStory`. ([#156](https://github.com/flipbook-labs/storyteller/pull/156))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.png" alt="Storybooks" height="18" align="texttop" /></picture> Type `mapStory` and `mapDefinition` values as `unknown`, so middleware narrows them before use. ([#146](https://github.com/flipbook-labs/storyteller/pull/146))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop" /></picture> Add contributor tooling for validating Storyteller builds in Flipbook and formatting Markdown. ([#152](https://github.com/flipbook-labs/storyteller/pull/152))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop" /></picture> Keep Flipbook integration overlays synchronized with Storyteller's exported types. ([#153](https://github.com/flipbook-labs/storyteller/pull/153))

### Fixes

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop" /></picture> Opening a story in a playtest no longer crashes. ([#221](https://github.com/flipbook-labs/storyteller/pull/221))

### Internal

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop" /></picture> Move to Changewrite v0.16.0 and AgentSkills v0.9.0. ([#213](https://github.com/flipbook-labs/storyteller/pull/213))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop" /></picture> Upgrade CodeQuality to v0.8.0 and turn long `--` comment runs into `--[[ ]]` blocks. ([#213](https://github.com/flipbook-labs/storyteller/pull/213))

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-dark.svg" /><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.svg" /><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.png" alt="Contributing" height="18" align="texttop" /></picture> Apply the Greptile changelog length rule to `summary` and let `body` run longer. ([#214](https://github.com/flipbook-labs/storyteller/pull/214))

## v1.13.0

Storyteller now renders stories written with Vide and Iris, and one module can hold several named stories. Every renderer applies a storybook's `mapStory` and `mapDefinition` the same way, discovery scans each place once, and Storybooks evaluate across several frames instead of all at once.

Features 6 · Changes 5 · Fixes 6 · Dependencies 6 · Internal 17

### Highlights

> <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> **Vide renderer**
>
> Add a Vide renderer so stories written with [Vide](https://github.com/centau/vide) can be previewed in a storybook. `createVideRenderer` implements the standard `StoryRenderer` interface (`mount`/`update`/`unmount`) and is selected automatically by `createRendererForStory` whenever a story's packages expose `Vide`. ([#128](https://github.com/flipbook-labs/storyteller/pull/128))

> <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> **Iris renderer**
>
> Add an [Iris](https://github.com/SirMallard/Iris) renderer so stories written with it can be previewed in a storybook. ([#125](https://github.com/flipbook-labs/storyteller/pull/125))

> <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.png" alt="Storybooks" height="18" align="texttop"></picture> **Multiple stories per module**
>
> Load multiple named Stories from one module and expose their IDs for selection. ([#155](https://github.com/flipbook-labs/storyteller/pull/155))

### Features

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Vide renderer ([#128](https://github.com/flipbook-labs/storyteller/pull/128))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Honor a storybook's `mapDefinition` middleware in the Fusion, Vide, and Manual renderers, matching the existing behavior in React and Roact. The definition is now transformed exactly once when a story mounts, regardless of which renderer is used. ([#137](https://github.com/flipbook-labs/storyteller/pull/137))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Iris renderer ([#125](https://github.com/flipbook-labs/storyteller/pull/125))
4. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Honor a storybook's `mapDefinition` middleware in the Iris renderer, matching the other renderers. The definition is transformed exactly once when a story mounts. ([#138](https://github.com/flipbook-labs/storyteller/pull/138))
5. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.png" alt="Storybooks" height="18" align="texttop"></picture> Multiple stories per module ([#155](https://github.com/flipbook-labs/storyteller/pull/155))
6. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-discovery-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-discovery-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-discovery-light.png" alt="Discovery" height="18" align="texttop"></picture> Expose read-only Charm getters for loaded, unavailable, and orphaned story discovery state. ([#160](https://github.com/flipbook-labs/storyteller/pull/160))

### Changes

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop"></picture> Load Stories through shared, prioritized requests while spreading Storybook evaluation across frames. ([#144](https://github.com/flipbook-labs/storyteller/pull/144))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-discovery-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-discovery-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-discovery-light.png" alt="Discovery" height="18" align="texttop"></picture> Discover stories and Storybooks through one ModuleScript scan and classification pass per store. ([#161](https://github.com/flipbook-labs/storyteller/pull/161))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-light.png" alt="Docs" height="18" align="texttop"></picture> Rewrite the README with a working example and install snippets for Wally and Lute. ([#208](https://github.com/flipbook-labs/storyteller/pull/208))
4. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-light.png" alt="Docs" height="18" align="texttop"></picture> Document the host-supplied `colorMode` and `themeName` story props, and deprecate `theme` in favor of `colorMode`. ([#165](https://github.com/flipbook-labs/storyteller/pull/165))
5. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop"></picture> Log StorytellerStore activity through Archivist. Set `_G.ENABLE_STORYTELLER_LOGS = true` to show it in Studio Output. ([#140](https://github.com/flipbook-labs/storyteller/pull/140))

### Fixes

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Apply a storybook's `mapStory` middleware in the Fusion, Vide, and Manual renderers, matching the existing behavior in React and Roact. ([#134](https://github.com/flipbook-labs/storyteller/pull/134))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Apply a storybook's `mapDefinition` middleware exactly once when the React renderer mounts a story, matching the other renderers. Control changes now re-render the already-mapped story rather than re-applying the middleware, so a non-idempotent `mapDefinition` no longer stacks transformations on every update. ([#137](https://github.com/flipbook-labs/storyteller/pull/137))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop"></picture> Loading a story that requires Storyteller no longer starts discovery or creates the shared store inside the story's sandbox. ([#147](https://github.com/flipbook-labs/storyteller/pull/147))
4. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-react-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-react-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-react-light.png" alt="React" height="18" align="texttop"></picture> Keep shared Storyteller discovery running until the last React consumer unmounts. ([#162](https://github.com/flipbook-labs/storyteller/pull/162))
5. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop"></picture> Keep loaded storybooks' and stories' `packages` mutable in Charm state. Legacy `react`/`roact` fields now load only into `packages`. ([#132](https://github.com/flipbook-labs/storyteller/pull/132))
6. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-storybooks-light.png" alt="Storybooks" height="18" align="texttop"></picture> Explain how to resolve matching Story names in an array when neither Story has an explicit `id`. ([#164](https://github.com/flipbook-labs/storyteller/pull/164))

<details>
<summary>Dependencies (6)</summary>

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Upgrade FlipbookBatteries `v0.11.0` → `v0.12.0` and Lute `v1.0.1-nightly.20260612` → `v1.0.1-nightly.20260701`, and align the toolchain (luau-lsp `1.68.1`, selene `0.31.0`, StyLua `2.5.2`, rocale-cli `0.1.3`, wally-package-types `1.6.2`). ([#129](https://github.com/flipbook-labs/storyteller/pull/129))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-docs-light.png" alt="Docs" height="18" align="texttop"></picture> Update the docs site's dependencies to resolve all open Dependabot alerts. ([#139](https://github.com/flipbook-labs/storyteller/pull/139))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-packages-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-packages-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-packages-light.png" alt="Packages" height="18" align="texttop"></picture> Add AgentSkills `v0.4.0` as a dev dependency so agents can bootstrap the shared skills library. ([#141](https://github.com/flipbook-labs/storyteller/pull/141))
4. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-packages-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-packages-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-packages-light.png" alt="Packages" height="18" align="texttop"></picture> Update AgentSkills to `v0.5.0` for the durable-writing workflow. ([#143](https://github.com/flipbook-labs/storyteller/pull/143))
5. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Upgrade Jest to v3.21.0 from Roblox's `roblox/*` Wally packages. String requires in tests resolve through `ScriptService:ResolveModulePath` on engines that support it. ([#204](https://github.com/flipbook-labs/storyteller/pull/204))
6. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-loading-light.png" alt="Loading" height="18" align="texttop"></picture> Upgrade ModuleLoader to v0.13.0, so `.config` aliases resolve in loaded stories and nested require errors print one stack. ([#209](https://github.com/flipbook-labs/storyteller/pull/209))

</details>

<details>
<summary>Internal (17)</summary>

1. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop"></picture> Upgrade the Changewrite release action to `v0.7.0` and adopt its `publish-lock` check. ([#141](https://github.com/flipbook-labs/storyteller/pull/141))
2. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-ci-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-ci-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-ci-light.png" alt="CI" height="18" align="texttop"></picture> Add a StorytellerStore benchmark suite behind a --benchmarks flag (`lute run test --benchmarks`) with a non-blocking CI job. Bench files use the .bench suffix and never run in the regular spec pass. ([#148](https://github.com/flipbook-labs/storyteller/pull/148))
3. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.png" alt="Contributing" height="18" align="texttop"></picture> Update the story-renderers contributing doc to match the real `StoryRenderer` contract: the `transformProps` and `shouldUpdate` hooks, the current `mount`, `update`, and `unmount` signatures, and Vide listed among the supported renderers. ([#136](https://github.com/flipbook-labs/storyteller/pull/136))
4. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop"></picture> Release automation reads the public Flipbook Backend App Client ID from an organization variable. ([#158](https://github.com/flipbook-labs/storyteller/pull/158))
5. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.png" alt="Contributing" height="18" align="texttop"></picture> Assign repository code ownership to the Flipbook Engine team. ([#159](https://github.com/flipbook-labs/storyteller/pull/159))
6. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-ci-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-ci-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-ci-light.png" alt="CI" height="18" align="texttop"></picture> Run cloud tests for fork pull requests from a prebuilt test place in a maintainer-approved job, and add a contributing guide. ([#169](https://github.com/flipbook-labs/storyteller/pull/169))
7. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop"></picture> Upgrade Changewrite to `v0.11.0`, so release notes mark each entry with a chip naming the part of Storyteller it changed and collapse the Dependencies and Internal sections. ([#176](https://github.com/flipbook-labs/storyteller/pull/176))
8. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Run the shared CodeQuality lint rules as part of `lute run lint`, reporting findings without failing. ([#171](https://github.com/flipbook-labs/storyteller/pull/171))
9. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Fix the CodeQuality lint findings and fail `lute run lint` when the rules report a new one. ([#173](https://github.com/flipbook-labs/storyteller/pull/173))
10. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-release-light.png" alt="Release" height="18" align="texttop"></picture> Upgrade Changewrite to `v0.12.0`. ([#199](https://github.com/flipbook-labs/storyteller/pull/199))
11. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Pin CodeQuality to v0.3.0 and read the lint rules from its `RULES_PATH` export. ([#201](https://github.com/flipbook-labs/storyteller/pull/201))
12. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Declare Lute tooling dependencies in `pkg.luau` on Lute `1.0.1-nightly.20261115`, with FlipbookBatteries `v0.13.0` and AgentSkills `v0.7.0`. ([#200](https://github.com/flipbook-labs/storyteller/pull/200))
13. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Manage the Lute tooling with `pkg.luau`, and ship `src/.config.luau` so Storyteller keeps its own aliases. ([#202](https://github.com/flipbook-labs/storyteller/pull/202))
14. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-contributing-light.png" alt="Contributing" height="18" align="texttop"></picture> Give Greptile repository rules for impact on Flipbook, tests, comments, and changelog entries. ([#205](https://github.com/flipbook-labs/storyteller/pull/205))
15. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-build-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-build-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-build-light.png" alt="Build" height="18" align="texttop"></picture> Build and install Storyteller without darklua. ([#203](https://github.com/flipbook-labs/storyteller/pull/203))
16. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-tooling-light.png" alt="Tooling" height="18" align="texttop"></picture> Lint without Selene. ([#206](https://github.com/flipbook-labs/storyteller/pull/206))
17. <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.svg"><img src="https://raw.githubusercontent.com/flipbook-labs/storyteller/main/.changes/assets/kind-renderers-light.png" alt="Renderers" height="18" align="texttop"></picture> Test renderer selection and each renderer's mount, update, and unmount lifecycle through `render()`. ([#135](https://github.com/flipbook-labs/storyteller/pull/135))

</details>

## v1.12.0

### Changes

- Mirror version to loom.config.luau in release workflow (#123) ([19aba2c](https://github.com/flipbook-labs/storyteller/commit/19aba2c5c2347965149becef9b01d8ec3fe4b10e))

- Bump FlipbookBatteries and Lute versions (#121) ([50c69d2](https://github.com/flipbook-labs/storyteller/commit/50c69d28c95fed70c547ee7d8c369a992ff90fba))

- Adopt Changewrite release workflow (#119) ([7d269ee](https://github.com/flipbook-labs/storyteller/commit/7d269ee8d0a4b78b18abdaf1f443433a758db38e))

## v1.11.0

### Changes

- Bump to 1.11.0 (#118) ([97c7b54](https://github.com/flipbook-labs/storyteller/commit/97c7b54557b8d0bf13162e706b496f873543c916))

- Upgrade Lute to v1.0.1-nightly.20260508 (#117) ([0e71f59](https://github.com/flipbook-labs/storyteller/commit/0e71f59fe049b7c656ebde4f3d625689780040ee))

- Provide names to our control types (#113) ([89d5ebb](https://github.com/flipbook-labs/storyteller/commit/89d5ebbecab8f52a001960daa02cb0eab3fae480))

- UI Labs compat tweaks (#115) ([af389e5](https://github.com/flipbook-labs/storyteller/commit/af389e51b8d8f7488e4cc1916146b4148a601007))

- Object control type (#116) ([4d8a4b0](https://github.com/flipbook-labs/storyteller/commit/4d8a4b0415718b174314194f209ecff6bc589c26))

- Stop spamming folks for reviews (#112) ([893021a](https://github.com/flipbook-labs/storyteller/commit/893021af4d9dce88619ea4c56f893c1b05d0c24b))

- Run tests with rocale-cli (#111) ([85212ab](https://github.com/flipbook-labs/storyteller/commit/85212abb9e6d743f9523fa6a8b320fce788d7e51))

## v1.10.0

### Changes

- Bump to 1.10.0 (#110) ([b1dd167](https://github.com/flipbook-labs/storyteller/commit/b1dd167a183f01d7bcd9a901f9abebc2598381fb))

- Properly sandbox Story environment (#81) ([5c28354](https://github.com/flipbook-labs/storyteller/commit/5c28354436576093f3eb572c2080d8545cd665ff))

## v1.9.0

### Changes

- Bump to 1.9.0 (#108) ([138f177](https://github.com/flipbook-labs/storyteller/commit/138f1776d0a8a18d6fc27215696ae06c7dd8cb6d))

- Forgot to add `.story` to some stories! (#107) ([d9fef11](https://github.com/flipbook-labs/storyteller/commit/d9fef114e31e53df76cd9f4494781d0c7ae12f79))

- Improve performance of Story/Storybook discovery (#103) ([b8418eb](https://github.com/flipbook-labs/storyteller/commit/b8418eb70d796307338da48b7f65ab0048161b71))

- Update API to export `isStorybookModule` (#106) ([7474151](https://github.com/flipbook-labs/storyteller/commit/7474151eb74829655a9ba2a6ca60c503609ebfec))

- Move Lute scripts to the `.lute` folder (#102) ([5616e36](https://github.com/flipbook-labs/storyteller/commit/5616e36a73e324f99a6520eaaeb3308ef7d47969))

## v1.8.1

### Changes

- Bump version to 1.8.1 (#101) ([a8e4d2b](https://github.com/flipbook-labs/storyteller/commit/a8e4d2b4747370f6b7c32553e7509ab39d015649))

- Initialize StorytellerStore lazily (#99) ([3c0ed08](https://github.com/flipbook-labs/storyteller/commit/3c0ed082098865cdf97d7134869f3cfdb8d0236a))

## v1.8.0

### Changes

- Bump version to 1.8.0 (#97) ([46fef13](https://github.com/flipbook-labs/storyteller/commit/46fef133cafc0bdb51d4a9843318207dcb74d4f5))

- Use Loom to install FlipbookBatteries (#96) ([c5f60b1](https://github.com/flipbook-labs/storyteller/commit/c5f60b17c8ed032b39c4ce353b529b02810dd70c))

- Port Signals to Charm (#95) ([930295d](https://github.com/flipbook-labs/storyteller/commit/930295d70f9c67794baae459fb2774590263adbb))

## v1.7.1

### Changes

- Bump to 1.7.1 (#91) ([7fb867b](https://github.com/flipbook-labs/storyteller/commit/7fb867b42d54361a929121ea90360cfdaf8a1cd6))

- Controls are migrated on load instead of hydration (#90) ([0f24a92](https://github.com/flipbook-labs/storyteller/commit/0f24a92258a028ccbb8403df2519ed7eaea948d7))

- Fix transformations for list-based controls (#89) ([8852568](https://github.com/flipbook-labs/storyteller/commit/8852568148858a1d449d5ffda22c2f694e6f4814))

## v1.7.0

### Changes

- Bump to 1.7.0 (#88) ([673401c](https://github.com/flipbook-labs/storyteller/commit/673401cffd1942c444758bbaea290bcc58448878))

- Export `hydrateControls` on the public API (#87) ([4d4f411](https://github.com/flipbook-labs/storyteller/commit/4d4f4110a1d2719aa2d7b6e4a0e9bd0fbe1a4b09))

## v1.6.0

### Changes

- Bump version to 1.6.0 (#86) ([8b7aa4a](https://github.com/flipbook-labs/storyteller/commit/8b7aa4a3262b34440d5800787a6f6dc74ede4e7f))

- Connect controls with rendering (#79) ([527a46b](https://github.com/flipbook-labs/storyteller/commit/527a46b1eadba3ee792d5b2feaeaac24b9cefcf8))

- Storyteller v1.5.0 controls migration (#84) ([0d0870a](https://github.com/flipbook-labs/storyteller/commit/0d0870a945d399de73f2331e03277dc44d0b03f0))

- API improvements for list-based control constructors (#85) ([510fcce](https://github.com/flipbook-labs/storyteller/commit/510fcce817a70477a40d41971bf1ed9dd80a7c14))

- Break down controls boundary (#82) ([fceb944](https://github.com/flipbook-labs/storyteller/commit/fceb944da66a423e37096fbd1a3f8fd60c34b41e))

- Runtime controls typechecking (#78) ([b516acd](https://github.com/flipbook-labs/storyteller/commit/b516acdec974bfe31360b15b893825fadb4f6b33))

- StoryContainer takes up the full size allowed to it (#80) ([d6ecab7](https://github.com/flipbook-labs/storyteller/commit/d6ecab75a062d7bb715091d8fc06503b57ad3816))

- Control migrations (#77) ([c05ef76](https://github.com/flipbook-labs/storyteller/commit/c05ef762ebd79ac98b27a30decdfe2f69ddc1320))

- Controls hydration API (#74) ([b8870e5](https://github.com/flipbook-labs/storyteller/commit/b8870e5320cfcec6e9495d3dbcbd9c99dc578483))

- Bump tool versions (#75) ([b63e38a](https://github.com/flipbook-labs/storyteller/commit/b63e38a2d0ab9e1457d7907e02b875488c0b305e))

## v1.5.0

### Changes

- Bump to 1.5.0 (#73) ([09ec236](https://github.com/flipbook-labs/storyteller/commit/09ec236aa628fea423e1e08a755da9ac6e3d20bd))

- Remove commented debug logs (#72) ([6b9e3d0](https://github.com/flipbook-labs/storyteller/commit/6b9e3d0933711e02f7915a510017f41eea62b7c1))

- React component for story rendering (#49) ([2ceb009](https://github.com/flipbook-labs/storyteller/commit/2ceb009b54444f74ef2195d64f43150522a85912))

- Flipbook batteries (#69) ([fdb24a7](https://github.com/flipbook-labs/storyteller/commit/fdb24a7d0e88d0ca2acf80605bad5f26f7cb0f17))

- Give all React code a single home (#71) ([87f430b](https://github.com/flipbook-labs/storyteller/commit/87f430bc5717679a312d8fafe6501234421010aa))

- Update createStory to take an arbitrary object (#70) ([2289d92](https://github.com/flipbook-labs/storyteller/commit/2289d92248410e3b508b509314814956ccb41177))

## v1.4.0

### Changes

- Bump to 1.4.0 (#68) ([17d47e2](https://github.com/flipbook-labs/storyteller/commit/17d47e28f6042e7f4aeed61694e8f23c7d18f099))

- Performance improvements for collections (#67) ([459a53e](https://github.com/flipbook-labs/storyteller/commit/459a53e20dbd99c06f703ebd61abb511cf3da5b2))

## v1.3.0

### Changes

- Bump to v1.3.0 (#66) ([807d5e1](https://github.com/flipbook-labs/storyteller/commit/807d5e1eee2314b0d4aabcc669c83438e99371ea))

- Analyze prod builds (#65) ([d66dcd0](https://github.com/flipbook-labs/storyteller/commit/d66dcd0ffb68bfa0d8802e64e52bbc28f2eb68ca))

- Instance collector (#59) ([831edf3](https://github.com/flipbook-labs/storyteller/commit/831edf38e12228aaa380e0fff7ff4f89659a4974))

- Install Signals and SignalsReact from Roblox's packages (#63) ([6c05b19](https://github.com/flipbook-labs/storyteller/commit/6c05b1937ab9504ab434d492efaac490142daef8))

- Add a flag to filter which tests get run (#62) ([a7cd4a9](https://github.com/flipbook-labs/storyteller/commit/a7cd4a995e57497d7be615b2b0ae253b0d3766f8))

## v1.2.0

### Changes

- Bump to 1.2.0 (#60) ([547ae0d](https://github.com/flipbook-labs/storyteller/commit/547ae0d5bde6d85465ee5749e8716ab5fc6978e7))

- Discovery of orphans with better DataModel awareness (#57) ([977d76e](https://github.com/flipbook-labs/storyteller/commit/977d76e186bb9934bd6d0090acdbb14ae6bc3d3e))

- Port scripts to Lute (#58) ([63a18b5](https://github.com/flipbook-labs/storyteller/commit/63a18b5678ede60a718c497ddc36ff759e07d8b2))

## v1.1.1

### Changes

- Bump ModuleLoader version to 0.7.0 (#54) ([bab67bd](https://github.com/flipbook-labs/storyteller/commit/bab67bd42797b4dc17d374db17b409354a770871))

## v1.1.0

### Changes

- Bump to v1.1.0 (#53) ([2626787](https://github.com/flipbook-labs/storyteller/commit/26267872bc47d8a65d4d4ffa1da34637ba10a03e))

- Static props (#52) ([de0683b](https://github.com/flipbook-labs/storyteller/commit/de0683b26c548e0c49402d5dc6428549a91b0202))

- Support passing in React using the `Roact` key (#46) ([66c9cdf](https://github.com/flipbook-labs/storyteller/commit/66c9cdf96667b47331fae61e314412d8c4f339bc))

- Naive substory support (#51) ([93d95db](https://github.com/flipbook-labs/storyteller/commit/93d95dba19546c6ba3e84202485103c089281863))

- Add `mapStory` and `mapDefinition` middleware (#47) ([031c63b](https://github.com/flipbook-labs/storyteller/commit/031c63bab292c19ff82587baa877435b6ec13395))

- Storybook groups (#50) ([1f7ccf8](https://github.com/flipbook-labs/storyteller/commit/1f7ccf86f739729a46e068fd8b81a1a3e13a1aa4))

- Map `storyRoot` to `storyRoots` (#48) ([8e66343](https://github.com/flipbook-labs/storyteller/commit/8e66343e400af3a6f9c46f29cd20305e85c8c12a))

- Orphan story discovery (#44) ([ca928a2](https://github.com/flipbook-labs/storyteller/commit/ca928a2186247ca24f06a67705e6b6ca00341876))

## v1.0.0

### Changes

- Bump version to v1.0.0 (#43) ([356c40b](https://github.com/flipbook-labs/storyteller/commit/356c40ba22c76638028885011f9172227c4d73b3))

- Add documentation for v1 (#22) ([7330cea](https://github.com/flipbook-labs/storyteller/commit/7330cea763fce9f06dea8ef3ee7e53fd1e7195fd))

- Modernizing (#42) ([76a892e](https://github.com/flipbook-labs/storyteller/commit/76a892e712ba18bac1c9574e968da50f4c587751))

- Tests for Fusion 0.3.0 (#41) ([1c211b8](https://github.com/flipbook-labs/storyteller/commit/1c211b8adce160cecd47addf7491f780383dbd7f))

- Add Fusion V3 support to controls (#39) ([a780818](https://github.com/flipbook-labs/storyteller/commit/a780818f954d8d94096e5f8b7001bc739e9497a8))

## v0.7.0

### Changes

- Version 0.7.0 (#38) ([e691cac](https://github.com/flipbook-labs/storyteller/commit/e691cac663c10a244ae45d68c2086bcd9e24c7bd))

- Hoist unavailable storybooks (#37) ([1c3d5dd](https://github.com/flipbook-labs/storyteller/commit/1c3d5dd2a7277da8547c2f3a2f91ebd3229879a2))

- Storybooks manage their own modulel loaders (#35) ([4c5d5cb](https://github.com/flipbook-labs/storyteller/commit/4c5d5cb824fb652b594e04dae87ab7c3980da90a))

- Run unit tests in CI (#36) ([33b2de9](https://github.com/flipbook-labs/storyteller/commit/33b2de92061a9a27a482c504273a0aa8d032ba42))

## v0.6.0

### Changes

- Bump to v0.6.0 (#34) ([4a8d182](https://github.com/flipbook-labs/storyteller/commit/4a8d1823fdbb340bbe84f466eadcb0f0dc5ca098))

- Add tests for React hooks (#31) ([5ce79da](https://github.com/flipbook-labs/storyteller/commit/5ce79da2813ad6ebb3a88807db4d5819d13aef83))

- Add support for nameless Storybooks (#28) ([ea274c3](https://github.com/flipbook-labs/storyteller/commit/ea274c386fd98717c1fb112aa09dc2a8ceb7d947))

## v0.5.0

### Changes

- Bump to 0.5.0 (#26) ([2b2ba84](https://github.com/flipbook-labs/storyteller/commit/2b2ba8425222c1717d6be284279ec9849b34a5c0))

- Fix support for legacy stories when packages are supplied on the storybook (#25) ([9732f3e](https://github.com/flipbook-labs/storyteller/commit/9732f3e6a0d786c4c99bb8510f1d77658e719e8d))

## v0.4.3

### Changes

- Accommodate analysis errors in flipbook's recent PR (#24) ([248fc07](https://github.com/flipbook-labs/storyteller/commit/248fc072de47699cb714187fbefc793ce5cd06b0))

## v0.4.2

### Changes

- Deploy to Wally from CI (#23) ([1e89a66](https://github.com/flipbook-labs/storyteller/commit/1e89a6673700ea6407d2a5964df47f22cff5a7ce))

## v0.4.1

### Changes

- Control updates dont collapse tables (#21) ([faa1625](https://github.com/flipbook-labs/storyteller/commit/faa1625632cd90c9c444a40974cdcabb73f9b730))

## v0.4.0

### Changes

- Fix Roact element rendering (#18) ([c443806](https://github.com/flipbook-labs/storyteller/commit/c44380636a517ad46b0c4298fac0d9b69b85e43c))

## v0.3.0

### Changes

- Bump to 0.3.0 (#17) ([fe72c72](https://github.com/flipbook-labs/storyteller/commit/fe72c72b3effb99595ed03ad6db179b8f97bed4e))

- Try getting docs working again (#16) ([f18296a](https://github.com/flipbook-labs/storyteller/commit/f18296a6964d7815534adbc72e233b9ae8ebbe0f))

- Remove duplicate deploy step (#15) ([3e0307a](https://github.com/flipbook-labs/storyteller/commit/3e0307ac5eba002566a941dbc3a0af67a5886736))

- Add API docs and general info (#14) ([2527d63](https://github.com/flipbook-labs/storyteller/commit/2527d636703fa3fc900bd8639bab0da859bd660a))

- More flipbook fixes (#13) ([9c5d5ec](https://github.com/flipbook-labs/storyteller/commit/9c5d5ece3c59e5f08e9adc2ec1bac6ac5a0759db))

- Implicit renderer (#6) ([cc7d3a3](https://github.com/flipbook-labs/storyteller/commit/cc7d3a30f3e858d802fdbe1343c7d697a51f8a6a))

## v0.2.1

### Changes

- Bump to 0.2.1 (#12) ([96692e2](https://github.com/flipbook-labs/storyteller/commit/96692e2a0349aae2b449fe2d0e3004e9e721ee64))

- Attempt to fix release workflow (#11) ([eed6bfa](https://github.com/flipbook-labs/storyteller/commit/eed6bfa24babc26694603cf6b5fb042d50da3041))

- Fix StreamingService crashing Story/Storybook discovery (#10) ([4d81e5e](https://github.com/flipbook-labs/storyteller/commit/4d81e5ee15ed3d960342fc18838304fe8d8e4ec4))

## v0.2.0

### Changes

- Bump version to v0.2.0 (#9) ([8a7f181](https://github.com/flipbook-labs/storyteller/commit/8a7f1814ff86d996bec68e02d1928d7c93200c87))

- Fusion support (#8) ([33ed4b4](https://github.com/flipbook-labs/storyteller/commit/33ed4b4dabae92958050a759346131efd5cee4e0))

- Stories are loaded the same as Storybooks (#7) ([290c65d](https://github.com/flipbook-labs/storyteller/commit/290c65d0166b77b2057411ac087e9f8df8ffc0c5))

- Add E2E tests (#5) ([714078c](https://github.com/flipbook-labs/storyteller/commit/714078cd1db29d176602e0660cd817b96e1eedfd))

- Fixes for flipbook (#2) ([7053a0b](https://github.com/flipbook-labs/storyteller/commit/7053a0b2c9d369756d7107691bc0eda01eacb250))

- Add initial readme (#3) ([2ff76fa](https://github.com/flipbook-labs/storyteller/commit/2ff76faac687e7d17982ffbcf1a78945d60227ab))

- Fix Wally package building (#4) ([5be6039](https://github.com/flipbook-labs/storyteller/commit/5be6039bc6a0b4aeb61994a27e03d7a904debf76))

- Rokit, not Foreman ([cd8448e](https://github.com/flipbook-labs/storyteller/commit/cd8448e7074201a93b720787e012a30365464db9))

## v0.1.1

### Changes

- Fix Wally build ([cc57e15](https://github.com/flipbook-labs/storyteller/commit/cc57e153c4b988f1ac6cf53613a1c47464ea73f7))

## v0.1.0

### Changes

- Add release workflow ([1ec159b](https://github.com/flipbook-labs/storyteller/commit/1ec159b1a83bc482760118df5dbcf3a2a833454d))

- Fix upload of build artifacts ([10dce7e](https://github.com/flipbook-labs/storyteller/commit/10dce7edd2dec18dfe51bafcd3b6f20a6313f129))

- Strict mode (#1) ([d52cfa1](https://github.com/flipbook-labs/storyteller/commit/d52cfa1186f0f3ac2abfc12beb7c80e73ec7031b))

- Update copyright holder ([863907e](https://github.com/flipbook-labs/storyteller/commit/863907efb2aed42ed9f6ba5e7f691507a47b9eb0))

- Bump luau-lsp to latest version ([f9ded86](https://github.com/flipbook-labs/storyteller/commit/f9ded86bd276f1a7d15c847d522973d8a42b1f68))

- Fix analysis breaking from a stray comma ([0bc4385](https://github.com/flipbook-labs/storyteller/commit/0bc43852a0f81d1dba234aca1302bbbecf9430d2))

- Fix more loadStoryModule tests ([c5bae4c](https://github.com/flipbook-labs/storyteller/commit/c5bae4c1e3094c425cabf44f268300d671fc50b3))

- Unit tests ([2c40962](https://github.com/flipbook-labs/storyteller/commit/2c40962d05716a5cc2e9d29f40884013016cc4b4))

- Fix path to render() ([abd500f](https://github.com/flipbook-labs/storyteller/commit/abd500f5cf821a128eddb17d989e043c85f54194))

- Initial commit ([e3d84ad](https://github.com/flipbook-labs/storyteller/commit/e3d84ad464468015855acb126038c0424aa61467))
