local types = require("@root/types")

local function createStory<T>(element: T): types.Story<T>
	return {
		name = "Sample",
		story = element,
		source = Instance.new("ModuleScript"),
		storybook = {
			storyRoots = {},
		},
	}
end

return createStory
