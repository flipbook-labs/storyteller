local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type LoadedStory<T> = types.LoadedStory<T>
type ModuleLoader = ModuleLoader.ModuleLoader

local function loadStoriesFromModule<T>(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): { LoadedStory<T> }
	return loadStoryModuleData(storyModule, storybook, providedLoader).stories
end

return loadStoriesFromModule
