local ModuleLoader = require("@pkg/ModuleLoader")
local t = require("@pkg/t")

type ModuleLoader = ModuleLoader.ModuleLoader

local types = {}

export type Theme = "Light" | "Dark"

-- https://storybook.js.org/docs/essentials/controls#annotation
type DetailedControlValue = {}

type ControlValue = string | number | boolean | DetailedControlValue

export type ControlSchema = {
	[string]: ControlValue | {},
}

export type StoryControls = {
	[string]: any,
}

export type ExtraStoryProps = {
	theme: Theme?,
}

export type StoryProps = {
	-- The top-level Instance that contains the UI being rendered
	container: Instance,
	-- The current UI theme
	theme: Theme,
	-- Controls added to the story that are used to modify it at runtime
	controls: StoryControls?,
}

export type RenderLifecycle = {
	update: (controls: StoryControls?) -> (),
	unmount: () -> (),
}

export type StoryRenderer<T> = {
	mount: (container: Instance, story: LoadedStory<T>, initialProps: StoryProps) -> (),
	unmount: (() -> ())?,
	update: ((props: StoryProps, prevProps: StoryProps?) -> ())?,
	transformProps: ((props: StoryProps, prevProps: StoryProps?) -> StoryProps)?,
	shouldUpdate: ((props: StoryProps, prevProps: StoryProps?) -> boolean)?,
}

export type StoryPackages = {
	[string]: any,
}

type MapStoryFn = (story: any) -> (props: StoryProps) -> any
type MapDefinitionFn = (story: any) -> any

export type Storybook = {
	storyRoots: { Instance },

	name: string?,
	packages: StoryPackages?,
	mapStory: MapStoryFn?,
	mapDefinition: MapDefinitionFn?,
}
types.IStorybook = t.interface({
	storyRoots = t.array(t.Instance),
	name = t.optional(t.string),
	packages = t.optional(t.map(t.string, t.any)),
})

export type LoadedStorybook = {
	name: string,
	storyRoots: { Instance },
	loader: ModuleLoader,
	source: ModuleScript,

	mapStory: MapStoryFn?,
	mapDefinition: MapDefinitionFn?,
	packages: StoryPackages?,
}

export type UnavailableStorybook = {
	problem: string,
	storybook: LoadedStorybook,
}

export type Story<T> = {
	story: T | (props: StoryProps) -> T,

	controls: StoryControls?,
	name: string?,
	packages: StoryPackages?,
	summary: string?,
	-- TODO: Double check if Developer Storybook lets you do this
	props: { [string]: any }?,
}
types.IStory = t.interface({
	story = t.any,
	name = t.optional(t.string),
	summary = t.optional(t.string),
	controls = t.optional(t.map(t.string, t.any)),
	packages = t.optional(t.map(t.string, t.any)),
})

export type LoadedStory<T> = {
	name: string,
	story: T | (props: StoryProps) -> T,
	source: ModuleScript,
	storybook: LoadedStorybook,
	packages: StoryPackages?,

	summary: string?,
	controls: StoryControls?,
	props: { [string]: any }?,
}

return types
