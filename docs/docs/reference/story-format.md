# Story Format

## Storybook

Any ModuleScript with a `.storybook` extension will be picked up as a Storybook.

The properties that can be used in the module are as follows:

| **Property**    | **Type**                            | **Description**                                                                                                                                                                                                                                                         |
| --------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `storyRoots`    | `{ Instance }`                      | Locations that the Storybook manages. Each instance will have its descendants searched for Story modules.                                                                                                                                                               |
| `name`          | `string?`                           | An optional name for the Storybook. Defaults to the module name with the extension removed. i.e. `Sample.storybook` becomes `Sample`.                                                                                                                                   |
| `packages`      | `{ [string]: any }?`                | An optional dictionary used for supplying the Storybook with the packages to use when rendering its Stories. This dictionary can also be supplied per-Story to change the renderer used, but it can be convenient to define your packages globally to avoid repetition. |
| `mapStory`      | `((story: any) -> (props) -> any)?` | Optional [middleware](#middleware) that wraps every rendered Story, e.g. to supply a shared context provider.                                                                                                                                                           |
| `mapDefinition` | `((story: any) -> any)?`            | Optional [middleware](#middleware) that transforms every Story's definition before it renders.                                                                                                                                                                          |

The most basic Storybook module can be represented as:

```lua title="Plain.storybook.luau"
return {
    storyRoots = {
        script.Parent.Components
    },
}
```

## Middleware

A Storybook can define middleware that runs against every Story it manages. This is handy for cross-cutting concerns like wrapping every Story in a theme provider or tagging Story names. Both hooks are optional and are honored by every renderer.

### mapStory

```lua
mapStory: (story) -> (props: StoryProps) -> element
```

`mapStory` wraps every Story with a component of your choosing. It receives the Story's component and returns a replacement component that renders in its place, which makes it the ideal spot to supply context providers or shared layout that each Story depends on.

```lua title="WithTheme.storybook.luau"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local ThemeContext = require(script.Parent.ThemeContext)

return {
    storyRoots = {
        script.Parent.Components,
    },
    packages = {
        React = React,
        ReactRoblox = ReactRoblox,
    },

    mapStory = function(story)
        return function(props)
            return React.createElement(ThemeContext.Provider, {
                value = "Dark",
            }, React.createElement(story, props))
        end
    end,
}
```

### mapDefinition

```lua
mapDefinition: (story) -> story
```

`mapDefinition` transforms a Story's definition before it is rendered. It receives the loaded Story and returns a (possibly modified) Story, so you can rewrite properties like `name`, adjust `controls`, or even swap out the `story` component entirely.

`mapDefinition` is applied exactly once, when the Story mounts. Control changes re-render the already-mapped Story rather than running the middleware again, so transformations that would be incorrect if applied repeatedly (such as wrapping or decorating the Story) remain stable across updates.

```lua title="WorkInProgress.storybook.luau"
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

    mapDefinition = function(story)
        local mapped = table.clone(story)
        mapped.name = `[WIP] {story.name}`
        return mapped
    end,
}
```

## Story

Any ModuleScript with a `.story` extension will be picked up as a Story when it is a descendant of one of the `storyRoots` that a Storybook manages.

Story modules can export one `story` or a non-empty `stories` collection.

| **Property** | **Type**                            | **Description**                                                                                                                                                                                                                             |
| ------------ | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `story`      | `<T>((props: StoryProps) -> T)?`    | A single Story. Required when `stories` is not provided.                                                                                                                                                                                    |
| `stories`    | `{ Story } \| { [string]: Story }?` | Multiple Stories from the same module. Arrays preserve author order. Dictionaries are ordered alphabetically by key, with each key supplying the Story's default name and ID.                                                               |
| `id`         | `string?`                           | An optional stable identifier for a Story within its module. Defaults to its explicit name, dictionary key, array index, or `default` for an unnamed single Story.                                                                          |
| `name`       | `string?`                           | The name of the Story as it appears in Flipbook. Defaults to the name of the Story module. i.e. `Sample.story` becomes `Sample`                                                                                                             |
| `summary`    | `string?`                           | A description of the Story that will appear above the rendered preview in Flipbook.                                                                                                                                                         |
| `controls`   | `{ [string]: any }?`                | Controls allow for on-the-fly configuration of your rendered UI. Read more about how to define and use controls [here](https://flipbook-labs.github.io/flipbook/docs/creating-stories/controls).                                            |
| `packages`   | `{ [string]: any }?`                | An optional dictionary used for supplying the Story with the packages to use when rendering. The Story inherits the packages defined by the Storybook, so this is mostly used in cases where Story needs to deviate from the usual renderer |

The type of the `story` property is dependent on what kind of Story is being rendered. Storyteller does not prescribe one particular way of writing Stories, or even a particular UI library that must be used.

### Multiple Stories

Fields defined beside `stories`, such as `controls`, `packages`, `props`, and `summary`, are inherited by each entry. Entries can override individual values. Dictionary values may be Story tables or Story functions for compatibility with Developer Storybook.

```lua title="Button.story.luau"
return {
    name = "Button",
    controls = {
        disabled = false,
    },
    stories = {
        {
            id = "primary",
            name = "Primary",
            story = function(props)
                -- ...
            end,
        },
        {
            id = "secondary",
            name = "Secondary",
            story = function(props)
                -- ...
            end,
        },
    },
}
```

## StoryProps

A Story's `story` function is passed in a `StoryProps` object that contains the following.

| **Property** | **Type**        | **Description**                                        |
| ------------ | --------------- | ------------------------------------------------------ |
| `container`  | `Instance`      |                                                        |
| `theme`      | `string`        | A string representing the current Roblox Studio theme. |
| `controls`   | `StoryControls` | Defaults to an empty table.                            |

If `props` is supplied on the Story, then the key/value pairs will be merged with `StoryProps`.

## Legacy package support

:::warning
A future version of Storyteller may remove this compatibility layer. It is recommended to migrate to `packages` in the meantime.
:::

UI libraries used to be supplied by attaching them as properties to a Story or Storybook. This has been superseded by the `packages` object, which acts as a dedicated location to supply the packages used for rendering Stories.

For backwards compatibility, the following properties are migrated to their `packages` equivalent:

| **Property**  | **Mapping**            |
| ------------- | ---------------------- |
| `fusion`      | `packages.Fusion`      |
| `react`       | `packages.React`       |
| `reactRoblox` | `packages.ReactRoblox` |
| `roact`       | `packages.Roact`       |
