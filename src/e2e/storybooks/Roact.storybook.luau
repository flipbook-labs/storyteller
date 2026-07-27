local Roact = require("@pkg/Roact")

local Root = script:FindFirstAncestor("e2e")

return {
	storyRoots = {
		Root.stories.roact,
	},
	packages = {
		Roact = Roact,
	},
}
