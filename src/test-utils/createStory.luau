local types = require("@root/types")

local function createStory<T>(element: T, packages: types.StoryPackages?): types.LoadedStory<T>
	return {
		name = "Sample",
		story = element,
		source = Instance.new("ModuleScript"),
		storybook = {
			storyRoots = {},
		},
		packages = packages,
	}
end

return createStory
