local ModuleLoader = require("@pkg/ModuleLoader")
local t = require("@pkg/t")

local ControlTypes = require("@root/controls/ControlTypes")

type ModuleLoader = ModuleLoader.ModuleLoader

export type StoryControlsSchema = ControlTypes.StoryControlsSchema
export type StoryControls = ControlTypes.StoryControls

local types = {}

export type StudioTheme = "Light" | "Dark"

export type ExtraStoryProps = {
	[string]: unknown,
}

export type ReservedStoryProps = {
	container: Instance,
	controls: StoryControls?,
	-- story: LoadedStory<unknown>
}

export type StoryProps = {
	[string]: unknown,
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
	[string]: unknown,
}

type MapStoryFn = (story: unknown) -> (props: StoryProps) -> unknown
type MapDefinitionFn = (story: unknown) -> unknown

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
types.IStoryDefinition = t.interface({
	story = t.any,
	id = t.optional(t.string),
	name = t.optional(t.string),
	summary = t.optional(t.string),
	controls = t.optional(t.map(t.string, t.any)),
	packages = t.optional(t.map(t.string, t.any)),
	props = t.optional(t.map(t.string, t.any)),
})

export type StoryEntry<T> = Story<T> | (props: StoryProps) -> T

export type StoryGroup<T> = {
	stories: { StoryEntry<T> } | { [string]: StoryEntry<T> },

	name: string?,
	summary: string?,
	controls: StoryControlsSchema?,
	packages: StoryPackages?,
	props: ExtraStoryProps?,
}
types.IStoryGroup = t.interface({
	-- Key discipline (array or string-keyed dictionary) is enforced by
	-- normalizeStoryModule so mixed keys surface an actionable error instead
	-- of a generic union failure.
	stories = t.table,
	name = t.optional(t.string),
	summary = t.optional(t.string),
	controls = t.optional(t.map(t.string, t.any)),
	packages = t.optional(t.map(t.string, t.any)),
	props = t.optional(t.map(t.string, t.any)),
})

export type StoryModule<T> = Story<T> | StoryGroup<T>
types.IStory = t.union(types.IStoryDefinition, types.IStoryGroup)

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

export type StoryRequest = {
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
}

export type StoryModuleRecord = {
	name: string?,
	stories: { LoadedStory<unknown> }?,
	problem: string?,
}

-- Records are keyed by (Story module, Storybook source) pair: the outer key is
-- the Story ModuleScript, the inner key is the ModuleScript of the Storybook it
-- was loaded through. The same Story module can be covered by multiple
-- Storybooks, and each pairing loads independently because the Storybook
-- supplies the loader environment (packages, mapStory, and friends).
export type StoryModuleRecords = {
	[ModuleScript]: {
		[ModuleScript]: StoryModuleRecord,
	},
}

return types
