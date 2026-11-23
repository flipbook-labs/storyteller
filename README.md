# Storyteller

Storyteller finds, loads, and renders UI stories in Roblox, and powers the [Flipbook](https://github.com/flipbook-labs/flipbook) storybook plugin. It loads stories without Roblox's `require` cache, so a storybook app picks up edits without restarting.

API reference lives at [flipbook-labs.github.io/storyteller](https://flipbook-labs.github.io/storyteller/api/Storyteller).

## Install

With Wally:

```toml
[dependencies]
Storyteller = "flipbook-labs/storyteller@1.13.0"
```

With Lute, add this to `pkg.luau` and run `lute pkg install --vendor`:

```luau
storyteller = {
	rev = "v1.13.0",
	sourceKind = "github",
	source = "https://github.com/flipbook-labs/storyteller",
},
```

## Use

Find a storybook, load one of its stories, and render it into any Instance:

```luau
local Storyteller = require("@pkg/Storyteller")

local storybookModule = Storyteller.findStorybookModules(game)[1]
local storybook = Storyteller.loadStorybookModule(storybookModule)

local storyModule = Storyteller.findStoryModulesForStorybook(storybook)[1]
local story = Storyteller.loadStoryModule(storyModule, storybook)

local container = Instance.new("ScreenGui")
container.Parent = game:GetService("StarterGui")
local lifecycle = Storyteller.render(container, story)

-- When the story closes:
lifecycle.unmount()
```

The load functions throw when a module fails to load, so wrap them in `pcall` in real code. Storybook apps built with React can use `StorytellerProvider`, `useStorybooks`, `useStory`, and `StoryContainer` instead. See the [API reference](https://flipbook-labs.github.io/storyteller/api/Storyteller) for every function.

## Story format

Storyteller treats any ModuleScript ending in `.storybook` as a storybook and any ending in `.story` as a story. See the [story format reference](https://flipbook-labs.github.io/storyteller/reference/story-format) for the fields each one takes.

## Renderers

Stories can render plain Roblox Instances, React, Roact, Fusion, Vide, or Iris. Storyteller picks the renderer from the packages a story or storybook provides. See [Story renderers](https://flipbook-labs.github.io/storyteller/contributing/story-renderers) to add one.

## Compatibility

Storyteller can load some stories written for [UI Labs](https://pepeeltoro41.github.io/ui-labs/) and [Hoarcekat](https://github.com/Kampfkarren/hoarcekat/).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT.
