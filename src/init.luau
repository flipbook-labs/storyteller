local ModuleLoader = require("@pkg/ModuleLoader")
local types = require("./types")

export type Story<T> = types.Story<T>
export type StoryControls = types.StoryControls
export type Storybook = types.Storybook
export type StoryProps<T> = types.StoryProps<T>
export type StoryRenderer<T> = types.StoryRenderer<T>

type API = {
	isStorybookModule: (instance: Instance) -> boolean,
	isStoryModule: (instance: Instance) -> boolean,

	-- loadStorybooks: (loader: ModuleLoader.ModuleLoader, parent: Instance) -> { Storybook },
	loadStory: <T>(
		loader: ModuleLoader.ModuleLoader,
		module: ModuleScript,
		storybook: Storybook
	) -> (Story<T>?, string?),

	render: <T>(
		renderer: StoryRenderer<T>,
		container: Instance,
		story: Story<T>,
		initialControls: StoryControls?
	) -> {
		update: (newControls: StoryControls?) -> (),
		unmount: () -> (),
	},

	createRendererForStory: <T>(story: Story<T>) -> StoryRenderer<T>,

	useStorybooks: (parent: Instance, loader: ModuleLoader.ModuleLoader) -> { Storybook },
	useStory: (
		module: ModuleScript,
		storybook: Storybook,
		loader: ModuleLoader.ModuleLoader
	) -> (Story<unknown>?, string?),

	createFusionRenderer: ({ Fusion: unknown }) -> StoryRenderer<Instance>,
	createReactRenderer: ({ React: unknown, ReactRoblox: unknown }) -> StoryRenderer<unknown>,
	createRoactRenderer: ({ Roact: unknown }) -> StoryRenderer<unknown>,
	createRobloxRenderer: () -> StoryRenderer<Instance>,
	-- createDeveloperStorybookRenderer: () -> StoryRenderer<unknown>,
	-- createHoarcekatRenderer: () -> StoryRenderer<unknown>,
}

local api: API = {
	isStorybookModule = require("./isStoryModule"),
	isStoryModule = require("./isStoryModule"),

	loadStory = require("./loadStoryModule"),
	render = require("./render"),
	createRendererForStory = require("./createRendererForStory"),

	useStory = require("./hooks/useStory"),
	useStorybooks = require("./hooks/useStorybooks"),

	createFusionRenderer = require("./renderers/createFusionRenderer"),
	createReactRenderer = require("./renderers/createReactRenderer"),
	createRoactRenderer = require("./renderers/createRoactRenderer"),
	createRobloxRenderer = require("./renderers/createRobloxRenderer"),
}

return api
