# Story Renderers

The render API allows any UI library to be supported as the renderer for a Storyteller story.

For each renderer, Storyteller provides a mounting point, context, and lifecycle hooks to handle rendering, lifetime, and cleanup.

## Supported renderers

| **Name**            | **Format**                                                                                                                              |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| React               | Result of `React.createElement` or a function that takes `props` as the first argument and creates an element                           |
| Roact               | Result of `Roact.createElement` or a function that takes `props` as the first argument and creates an element                           |
| Fusion              | Result of `Fusion.New` or a function that takes `props` as the first argument and creates an Instance                                   |
| Vide                | A function that takes `props` as the first argument and returns an Instance, or a pre-created Instance                                  |
| Manual              | A function that takes `props` as the first argument and returns an Instance                                                             |
| Functional (Legacy) | A function that takes `target` as the first argument, `props` as the second, and optionally returns a function for manually cleaning up |
| Hoarcekat (Legacy)  | Same as `Functional (Legacy)` but the story file itself is represented by a function                                                    |

Future:
- [Blend](https://quenty.github.io/NevermoreEngine/api/Blend/)
- Developer Storybook (Roblox internal)

## Adding new renderers

All renderers live here: https://github.com/flipbook-labs/storyteller/tree/main/src/renderers.

When writing tests for a renderer, the `render` function must be used to ensure each renderer behaves properly with lifecycles.

When adding a new renderer, use the existing ones as reference and use the below API docs to hook up all necessary behavior for your UI library.

## API

### Props

#### theme

`theme: "Dark" | "Light"`

Deprecated. This prop is always `"Dark"` and is only kept for backwards compatibility. Hosts like Flipbook supply the real theme themselves via extra props.

#### container

`container: Instance`

The location where GuiObjects will be rendered to.

#### story

`story: Story`

Reference to the Story that is being rendered.

#### story.storybook

`story.storybook: LoadedStorybook`

Reference to the Storybook that the Story is a part of, available on the `story` prop.

#### controls

`controls: { [string]: any }`

All the values provided by the story controls. The contents of this vary based on the story being rendered.

### Renderer

```lua
export type StoryRenderer<T> = {
	mount: (container: Instance, story: LoadedStory<T>, initialProps: StoryProps) -> (),
	unmount: (() -> ())?,
	update: ((props: StoryProps, prevProps: StoryProps?) -> ())?,
	transformProps: ((props: StoryProps, prevProps: StoryProps?) -> StoryProps)?,
	shouldUpdate: ((props: StoryProps, prevProps: StoryProps?) -> boolean)?,
}
```

#### mount

`mount(container: Instance, story: LoadedStory<T>, initialProps: StoryProps)`

This function handles the initial mounting of a UI element to the container. The story being rendered is available as `story.story`.

If the renderer does not define `update`, `mount` is also called for every update (a full remount), guarded by `shouldUpdate` when defined.

#### update

`update(props: StoryProps, prevProps: StoryProps?)`

Called any time the story's props change, typically from the user interacting with story controls. By comparing `props` and `prevProps` a renderer can choose how it wants to re-render the story.

This hook is optional. When it is defined, the renderer is responsible for reflecting the new props in the rendered UI. For example, Fusion keeps its Instances' identities stable by pushing new control values through `Fusion.Value` objects. When it is not defined, the story is unmounted and remounted from scratch with the new props.

#### unmount

`unmount()`

Called when a story is closed. This function handles cleanup for the `mount` function so there are no lingering UI elements between stories. After it runs, the container's remaining children are cleared automatically.

#### transformProps

`transformProps(props: StoryProps, prevProps: StoryProps?): StoryProps`

This optional hook is called before `mount` and `update` in order to transform the props provided to them. The `prevProps` are the transformed props from the previous render, so a renderer can carry state across renders.

For example, a renderer for a reactive UI library can map each value in `props.controls` to that library's state primitive (like `Fusion.Value` or `Vide.source`) so stories receive reactive state, reusing the previous render's objects on update to keep Instance identities stable.

#### shouldUpdate

`shouldUpdate(props: StoryProps, prevProps: StoryProps?): boolean`

This optional hook gates the remount path: when the renderer has no `update` function, every update calls `mount` again, and returning `false` from `shouldUpdate` skips that remount. It is also consulted for the initial mount, where `prevProps` is `nil`.

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
