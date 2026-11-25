local ModuleLoader = require("@pkg/ModuleLoader")
local gt = require("@pkg/GreenTea")
local t = require("@pkg/t")

local ControlTypes = require("@root/controls/ControlTypes")

type ModuleLoader = ModuleLoader.ModuleLoader

export type StoryControlsSchema = ControlTypes.StoryControlsSchema
export type StoryControls = ControlTypes.StoryControls

local types = {}

export type StudioTheme = "Light" | "Dark"

--[[
	Hosts pass extra props that stories read directly. With `unknown` values,
	every story would need a cast to use one, and Luau's old solver, which
	Storyteller type checks with, would reject the tables of props hosts pass.
	#193 tracks removing this ignore.
]]
-- lute-lint-ignore(no_any)
export type ExtraStoryProps = {
	[string]: any,
}

export type ReservedStoryProps = {
	container: Instance,
	controls: StoryControls?,
	-- story: LoadedStory<unknown>
}

--[[
	Stories read their props directly, as in `props.controls.text`. With
	`unknown` values, every story would need a cast to use a prop, and Luau's old
	solver, which Storyteller type checks with, would reject the tables of props
	that callers pass.
	#194 tracks removing this ignore.
]]
-- lute-lint-ignore(no_any)
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

--[[
	Storyteller type checks with Luau's old solver, which rejects a table like
	`{ React = React }` where `{ [string]: unknown }` is expected. With `unknown`
	here, storybooks that annotate their packages would stop type checking.
	#195 tracks removing this ignore.
]]
-- lute-lint-ignore(no_any)
export type StoryPackages = {
	[string]: any,
}

--[[
	A storybook's mapStory and mapDefinition receive stories made with whatever
	UI library the storybook uses, and return values that library understands.
	With `unknown`, a storybook couldn't use the story it's given without a cast.
	#196 tracks removing this ignore.
]]
-- lute-lint-ignore(no_any)
type MapStoryFn = (story: any) -> (props: StoryProps) -> any
-- #197 tracks removing this ignore.
-- lute-lint-ignore(no_any)
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
-- A dictionary read from Story source before its values have been checked.
local UnknownDict = gt.dictionary(gt.string(), gt.unknown())
export type UnknownDict = typeof(UnknownDict)

local StoryDefinitionSource = gt.struct({
	story = gt.unknown(),
	id = gt.optional(gt.string()),
	name = gt.optional(gt.string()),
	summary = gt.optional(gt.string()),
	controls = gt.optional(UnknownDict),
	packages = gt.optional(UnknownDict),
	props = gt.optional(UnknownDict),
})
types.IStoryDefinitionSource = gt.build(StoryDefinitionSource)
export type StoryDefinitionSource = typeof(StoryDefinitionSource)

export type StoryEntry<T> = Story<T> | (props: StoryProps) -> T

export type StoryGroup<T> = {
	stories: { StoryEntry<T> } | { [string]: StoryEntry<T> },

	name: string?,
	summary: string?,
	controls: StoryControlsSchema?,
	packages: StoryPackages?,
	props: ExtraStoryProps?,
}
local StoryGroupSource = gt.struct({
	-- Key discipline (array or string-keyed dictionary) is enforced by
	-- normalizeStoryModule so mixed keys surface an actionable error instead
	-- of a generic union failure.
	stories = gt.table({ [gt.unknown()] = gt.unknown() }),
	name = gt.optional(gt.string()),
	summary = gt.optional(gt.string()),
	controls = gt.optional(UnknownDict),
	packages = gt.optional(UnknownDict),
	props = gt.optional(UnknownDict),
})
types.IStoryGroupSource = gt.build(StoryGroupSource)
export type StoryGroupSource = typeof(StoryGroupSource)

export type StoryModule<T> = Story<T> | StoryGroup<T>
local StoryModuleSource = gt.union(StoryDefinitionSource, StoryGroupSource)
types.IStoryModuleSource = gt.build(StoryModuleSource)
export type StoryModuleSource = typeof(StoryModuleSource)

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

export type LoadedStoryModule = {
	status: "Loaded",
	name: string,
	stories: { LoadedStory<unknown> },
}

export type UnavailableStoryModule = {
	status: "Unavailable",
	problem: string,
}

export type StoryModuleRecord = LoadedStoryModule | UnavailableStoryModule

-- Records are grouped by Storybook source, then keyed by Story module. Each
-- pairing loads independently because the Storybook supplies the loader
-- environment (packages, mapStory, and friends).
export type StoryModuleRecords = {
	[ModuleScript]: {
		[ModuleScript]: StoryModuleRecord,
	},
}

return types
