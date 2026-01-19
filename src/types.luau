local ModuleLoader = require("@pkg/ModuleLoader")
local t = require("@pkg/t")

local ControlTypes = require("@root/controls/ControlTypes")

type ModuleLoader = ModuleLoader.ModuleLoader

export type StoryControlsSchema = ControlTypes.StoryControlsSchema
export type StoryControls = ControlTypes.StoryControls

local types = {}

export type StudioTheme = "Light" | "Dark"

export type ExtraStoryProps = {
	[string]: any,
}

export type ReservedStoryProps = {
	container: Instance,
	controls: StoryControls?,
	-- story: LoadedStory<unknown>
}

export type StoryProps = {
	[string]: any,
}

export type RenderLifecycle = {
	update: (controls: StoryControls?, extraProps: ExtraStoryProps?) -> (),
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

	controls: StoryControlsSchema?,
	name: string?,
	packages: StoryPackages?,
	summary: string?,
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
	controls: StoryControlsSchema?,
	props: { [string]: any }?,
}

return types
