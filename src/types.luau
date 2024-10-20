export type StudioTheme = "Light" | "Dark"

export type StoryControls = {
	[string]: string | number | boolean,
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

export type Storybook = {
	storyRoots: { Instance },

	name: string?,
	packages: {
		[string]: any,
	}?,
}

export type Story<T> = {
	name: string,
	story: T | (props: StoryProps<T>) -> T,
	source: ModuleScript,
	storybook: Storybook,

	summary: string?,
	controls: StoryControls?,
}

return nil
