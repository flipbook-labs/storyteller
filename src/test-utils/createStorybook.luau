local ModuleLoader = require("@pkg/ModuleLoader")

local types = require("@root/types")

local function createStorybook(): types.LoadedStorybook
	return {
		name = "Storybook",
		loader = ModuleLoader.new(),
		source = Instance.new("ModuleScript"),
		storyRoots = {},
	}
end

return createStorybook
