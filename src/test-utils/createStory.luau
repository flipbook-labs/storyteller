local ModuleLoader = require("@pkg/ModuleLoader")
local Sift = require("@pkg/Sift")

local types = require("@root/types")

local function createStory<T>(partial: {
	story: T,
	[string]: any,
}): types.LoadedStory<T>
	return Sift.Dictionary.join({
		name = "Sample",
		source = Instance.new("ModuleScript"),
		storybook = {
			name = "Storybook",
			loader = ModuleLoader.new(),
			source = Instance.new("ModuleScript"),
			storyRoots = {},
		},
	}, partial)
end

return createStory
