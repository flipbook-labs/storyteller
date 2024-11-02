local types = require("@root/types")

local function createStory<T>(element: T, packages: types.StoryPackages?): types.Story<T>
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
