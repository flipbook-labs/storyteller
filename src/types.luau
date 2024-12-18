local ModuleLoader = require("@pkg/ModuleLoader")
local t = require("@pkg/t")

type ModuleLoader = ModuleLoader.ModuleLoader

local types = {}

export type StudioTheme = "Light" | "Dark"

export type StoryControls = {
	[string]: any,
}

export type StoryProps = {
	container: Instance,
	theme: StudioTheme,
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

type MapStory = (props: StoryProps) -> any

type RobloxInternalStorybook = {
	storyRoots: { Instance },

	name: string?,
	mapStory: ((story: any) -> (props: StoryProps) -> any)?,

	roact: any,
	react: any,
	reactRoblox: any,
}

export type Storybook = {
	storyRoots: { Instance },

	name: string?,
	packages: StoryPackages?,
	mapStory: ((story: any) -> (props: StoryProps) -> any)?,
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

	packages: StoryPackages?,
}

export type Story<T> = {
	story: T | (props: StoryProps) -> T,

	controls: StoryControls?,
	name: string?,
	packages: StoryPackages?,
	summary: string?,
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
}

return types
