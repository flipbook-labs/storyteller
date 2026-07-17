local ModuleLoader = require("@pkg/ModuleLoader")

local loadStoryModuleData = require("@root/loadStoryModuleData")
local types = require("@root/types")

type LoadedStorybook = types.LoadedStorybook
type ModuleLoader = ModuleLoader.ModuleLoader
type StoryModuleSnapshot = types.StoryModuleSnapshot

--[=[
	Loads the lightweight metadata needed to represent a Story module in a
	story browser. The module is evaluated, but no Story is rendered.

	@tag Story
	@tag Module Loading
	@within Storyteller
]=]
local function loadStoryModuleSnapshot(
	storyModule: ModuleScript,
	storybook: LoadedStorybook,
	providedLoader: ModuleLoader?
): StoryModuleSnapshot
	local data = loadStoryModuleData(storyModule, storybook, providedLoader)
	local stories = {}

	for _, story in data.stories do
		table.insert(stories, {
			id = story.id,
			name = story.name,
			summary = story.summary,
		})
	end

	return {
		name = data.name,
		source = storyModule,
		stories = stories,
	}
end

return loadStoryModuleSnapshot
