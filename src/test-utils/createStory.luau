local ModuleLoader = require("@pkg/ModuleLoader")

local types = require("@root/types")

local function createStory<T>(element: T, packages: types.StoryPackages?): types.LoadedStory<T>
	return {
		name = "Sample",
		story = element,
		source = Instance.new("ModuleScript"),
		storybook = {
			name = "Storybook",
			loader = ModuleLoader.new(),
			source = Instance.new("ModuleScript"),
			storyRoots = {},
		},
		packages = packages,
	}
end

return createStory
