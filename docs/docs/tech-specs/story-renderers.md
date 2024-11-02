# Story Renderers Spec

The render API allows any UI library to be supported as the renderer for a Storyteller story.

For each renderer, Storyteller provides a mounting point, context, and lifecycle hooks to handle rendering, lifetime, and cleanup.

## Supported renderers

| **Name**            | **Format**                                                                                                                              |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| React               | Result of `React.createElement` or a function that takes `props` as the first argument and creates an element                           |
| Roact               | Result of `Roact.createElement` or a function that takes `props` as the first argument and creates an element                           |
| Fusion              | Result of `Fusion.New` or a function that takes `props` as the first argument and creates an Instance                                   |
| Manual              | A function that takes `props` as the first argument and returns an Instance                                                             |
| Functional (Legacy) | A function that takes `target` as the first argument, `props` as the second, and optionally returns a function for manually cleaning up |
| Hoarcekat (Legacy)  | Same as `Functional (Legacy)` but the story file itself is represented by a function                                                    |

Future:
- [Vide](https://centau.github.io/vide/)
- [Blend](https://quenty.github.io/NevermoreEngine/api/Blend/)
- Developer Storybook (Roblox internal)

## Implementing a renderer

All renderers live here: https://github.com/flipbook-labs/storyteller/tree/main/src/renderers.

When writing tests for a renderer, the `render` function must be used to ensure each renderer behaves properly with lifecycles.

When adding a new renderer, use the existing ones as reference and use the below API docs to hook up all necessary behavior for your UI library.

## API

### Props

#### theme

`theme: "Dark" | "Light"`

The name of the current Roblox Studio theme.

#### container

`container: Instance`

The location where GuiObjects will be rendered to.

#### story

`story: Story`

Reference to the Story that is being rendered.

#### storybook

`storybook: Storybook`

Reference to the Storybook that the Story is a part of.

#### controls

`controls: { [string]: any }`

All the values provided by the story controls. The contents of this vary based on the story being rendered.

### Renderer

```lua
export type Renderer = {
	mount: (container: Instance, element: unknown, context: Context) -> GuiObject | Folder,
	update: ((controls: StoryControls<T>) -> ())?,

	transformArgs: ((args: Args, context: Context) -> Args)?,
	shouldUpdate: ((context: Context, prevContext: Context?) -> boolean)?,
	unmount: ((context: Context) -> ())?,
}
```

#### mount

`mount(container: Instance, element: unknown, context: RenderContext)`

This function handles the initial mounting of a UI element to the container.

The first two arguments `container` and `element` are provided for convenience and are identical to `context.container` and `context.story.story`, respectively.

#### update

`update(context: RenderContext, prevContext: RenderContext)`

Called any time something changes to RenderContext and determines if the story should re-render, and how.

This is a general purpose function for handling any context change. For example, by comparing `context` and `prevContext` a renderer can choose how it wants to re-render a story when controls change. In the case of Roact new GuiObjects are created, whereas Fusion relies on stable identities and instead relies on `transformContext` to

#### unmount

`unmount()`

Called when a story is closed. This function handles cleanup for the `mount` function so there are no lingering UI elements between stories.

#### transformContext

`transformContext(context: RenderContext, prevContext: RenderContext?): RenderContext`

This function is always called before `mount` and `update` in order to transform the RenderContext object provided to them.

For the Fusion renderer, `context.controls` has each of its values mapped to `Fusion.Value`, and if `prevContext` is supplied then each Value has `:set()` called on it. This ensures the rendered GuiObjects maintain stable identities, while still updating from changes to controls.

## Usage

### React

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

return {
	storyRoots = {
		script.Parent.Components,
	},
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
```

### Fusion

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

return {
	storyRoots = {
		script.Parent.Components,
	},
	packages = {
		Fusion = Fusion,
	},
}
```
