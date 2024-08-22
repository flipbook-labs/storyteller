export type StudioTheme = "Light" | "Dark"

export type Controls = {
	[string]: string | number | boolean,
}

export type Context<T> = {
	theme: StudioTheme,
	story: Story<T>,
	storybook: Storybook,
	container: Instance,
}

export type StoryRenderer<T> = {
	mount: (container: Instance, story: Story<T>, props: StoryProps<T>) -> (),

	unmount: (() -> ())?,
	update: ((story: Story<T>, prevStory: Story<T>) -> ())?,
	transformContext: ((context: Context<T>, prevContext: Context<T>?) -> Context<T>)?,
	shouldUpdate: ((context: Context<T>, prevContext: Context<T>?) -> boolean)?,
}

export type Storybook = {
	storyRoots: { Instance },
	name: string?,
}

export type Story<T> = {
	name: string,
	story: T | (props: StoryProps<T>) -> T,
	source: ModuleScript,
	storybook: Storybook,

	summary: string?,
	controls: Controls?,
}

export type StoryProps<T> = {
	controls: Controls,
	story: Story<T>,
	storybook: Storybook,
	container: Instance,
	theme: StudioTheme,
}

export type API = {
	isStorybookModule: (module: ModuleScript) -> boolean,
	isStoryModule: (module: ModuleScript) -> boolean,
	loadStorybooks: (loader: unknown, parent: Instance) -> { Storybook },
	loadStory: <T>(loader: unknown, module: ModuleScript, storybook: Storybook) -> (Story<T>?, string?),
	render: <T, K>(
		renderer: StoryRenderer<T>,
		story: Story<K>,
		container: Instance
	) -> {
		update: () -> (),
		unmount: () -> (),
	},

	FusionRenderer: StoryRenderer<unknown>,
	ReactRenderer: StoryRenderer<unknown>,
	RoactRenderer: StoryRenderer<unknown>,
	RobloxRenderer: StoryRenderer<unknown>,
	DeveloperStorybookRenderer: StoryRenderer<unknown>,
	HoarcekatRenderer: StoryRenderer<unknown>,
}

return {}
