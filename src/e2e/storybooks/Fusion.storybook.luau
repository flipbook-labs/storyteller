local Fusion = require("@pkg/Fusion")

local Root = script:FindFirstAncestor("e2e")

return {
	storyRoots = {
		Root.stories.fusion,
	},
	packages = {
		Fusion = Fusion,
	},
}
