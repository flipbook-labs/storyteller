local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type ModuleLoader = ModuleLoader.ModuleLoader

--[=[
	Loads every Story definition exported by a Story module.

	A module can export one `story`, an ordered `stories` array, or a
	Developer Storybook-compatible `stories` dictionary. Dictionary entries
	are returned alphabetically by key.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function loadStoriesFromModule<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): { LoadedStory<T> }
	return loadStoryModuleData(storyModule, storybook, providedLoader).stories
end

return loadStoriesFromModule
