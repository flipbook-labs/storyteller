local Vide = require("@pkg/Vide")

local Root = script:FindFirstAncestor("e2e")

return {
	storyRoots = {
		Root.stories.vide,
	},
	packages = {
		Vide = Vide,
	},
}
