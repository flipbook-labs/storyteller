local ModuleLoader = require("@pkg/ModuleLoader")
local gt = require("@pkg/GreenTea")
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

	id: string?,
	controls: StoryControlsSchema?,
	name: string?,
	packages: StoryPackages?,
	summary: string?,
	props: ExtraStoryProps?,
}
local StringMap = gt.dictionary(gt.string(), gt.unknown())
local StoryDefinition = gt.struct({
	story = gt.unknown(),
	id = gt.optional(gt.string()),
	name = gt.optional(gt.string()),
	summary = gt.optional(gt.string()),
	controls = gt.optional(StringMap),
	packages = gt.optional(StringMap),
	props = gt.optional(StringMap),
})
types.IStoryDefinition = gt.build(StoryDefinition)

export type StoryEntry<T> = Story<T> | (props: StoryProps) -> T

export type StoryGroup<T> = {
	stories: { StoryEntry<T> } | { [string]: StoryEntry<T> },

	name: string?,
	summary: string?,
	controls: StoryControlsSchema?,
	packages: StoryPackages?,
	props: ExtraStoryProps?,
}
local StoryGroup = gt.struct({
	-- Key discipline (array or string-keyed dictionary) is enforced by
	-- normalizeStoryModule so mixed keys surface an actionable error instead
	-- of a generic union failure.
	stories = gt.table({ [gt.unknown()] = gt.unknown() }),
	name = gt.optional(gt.string()),
	summary = gt.optional(gt.string()),
	controls = gt.optional(StringMap),
	packages = gt.optional(StringMap),
	props = gt.optional(StringMap),
})
types.IStoryGroup = gt.build(StoryGroup)

export type StoryModule<T> = Story<T> | StoryGroup<T>
types.IStory = gt.build(gt.union(StoryDefinition, StoryGroup))

export type LoadedStory<T> = {
	id: string,
	name: string,
	story: T | (props: StoryProps) -> T,
	source: ModuleScript,
	storybook: LoadedStorybook,
	packages: StoryPackages?,

	summary: string?,
	controls: StoryControlsSchema?,
	props: ExtraStoryProps?,
}

return types
