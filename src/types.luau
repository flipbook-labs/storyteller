local t = require("@pkg/t")

local types = {}

export type StudioTheme = "Light" | "Dark"

export type StoryControls = {
	[string]: any,
}

export type StoryProps<T> = {
	container: Instance,
	story: Story<T>,
	theme: StudioTheme,
	controls: StoryControls?,
}

export type StoryRenderer<T> = {
	mount: (container: Instance, story: Story<T>, initialProps: StoryProps<T>) -> (),
	unmount: (() -> ())?,
	update: ((props: StoryProps<T>, prevProps: StoryProps<T>?) -> ())?,
	transformProps: ((props: StoryProps<T>, prevProps: StoryProps<T>?) -> StoryProps<T>)?,
	shouldUpdate: ((props: StoryProps<T>, prevProps: StoryProps<T>?) -> boolean)?,
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
	story: T | (props: StoryProps<T>) -> T,
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
