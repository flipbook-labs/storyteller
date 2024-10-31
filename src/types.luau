local t = require("@pkg/t")

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

export type StoryRenderer<T> = {
	mount: (container: Instance, story: Story<T>, initialProps: StoryProps) -> (),
	unmount: (() -> ())?,
	update: ((props: StoryProps, prevProps: StoryProps?) -> ())?,
	transformProps: ((props: StoryProps, prevProps: StoryProps?) -> StoryProps)?,
	shouldUpdate: ((props: StoryProps, prevProps: StoryProps?) -> boolean)?,
}

export type StoryPackages = {
	[string]: any,
}

export type Storybook = {
	storyRoots: { Instance },

	name: string?,
	packages: StoryPackages?,
}
types.IStorybook = t.interface({
	storyRoots = t.array(t.Instance),
	name = t.optional(t.string),
	packages = t.optional(t.map(t.string, t.any)),
})

export type Story<T> = {
	name: string,
	story: T | (props: StoryProps) -> T,
	source: ModuleScript,
	storybook: Storybook,
	packages: StoryPackages?,

	summary: string?,
	controls: StoryControls?,
}
types.IStory = t.interface({
	story = t.any,
	name = t.optional(t.string),
	summary = t.optional(t.string),
	controls = t.optional(t.map(t.string, t.any)),
	packages = t.optional(t.map(t.string, t.any)),
})

return types
