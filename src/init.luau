local ModuleLoader = require("@pkg/ModuleLoader")
local types = require("./types")

export type Story<T> = types.Story<T>
export type StoryControls = types.StoryControls
export type Storybook = types.Storybook
export type StoryProps<T> = types.StoryProps<T>
export type StoryRenderer<T> = types.StoryRenderer<T>

type API = {
	isStorybookModule: (module: ModuleScript) -> boolean,
	isStoryModule: (module: ModuleScript) -> boolean,
	-- loadStorybooks: (loader: ModuleLoader.ModuleLoader, parent: Instance) -> { Storybook },
	loadStory: <T>(
		loader: ModuleLoader.ModuleLoader,
		module: ModuleScript,
		storybook: Storybook
	) -> (Story<T>?, string?),
	findStorybookModules: (parent: Instance) -> { ModuleScript },

	render: <T>(
		renderer: StoryRenderer<T>,
		container: Instance,
		story: Story<T>,
		initialControls: StoryControls?
	) -> {
		update: (newControls: StoryControls?) -> (),
		unmount: () -> (),
	},

	createFusionRenderer: ({ Fusion: unknown }) -> StoryRenderer<Instance>,
	createReactRenderer: ({ React: unknown, ReactRoblox: unknown }) -> StoryRenderer<unknown>,
	createRoactRenderer: ({ Roact: unknown }) -> StoryRenderer<unknown>,
	createRobloxRenderer: () -> StoryRenderer<Instance>,
	-- createDeveloperStorybookRenderer: StoryRenderer<unknown>,
	-- createHoarcekatRenderer: StoryRenderer<unknown>,
}

local api: API = {
	isStorybookModule = require("./isStoryModule"),
	isStoryModule = require("./isStoryModule"),
	findStorybookModules = require("./findStorybookModules"),

	loadStory = require("./loadStoryModule"),
	render = require("./render"),

	createFusionRenderer = require("./renderers/createFusionRenderer"),
	createReactRenderer = require("./renderers/createReactRenderer"),
	createRoactRenderer = require("./renderers/createRoactRenderer"),
	createRobloxRenderer = require("./renderers/createRobloxRenderer"),
}

return api
