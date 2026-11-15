local Iris = require("@pkg/Iris")

local Root = script:FindFirstAncestor("e2e")

return {
	storyRoots = {
		Root.stories.iris,
	},
	packages = {
		Iris = Iris,
	},
}
