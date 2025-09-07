local Root = script:FindFirstAncestor("e2e")

local Roact = require("@pkg/Roact")

return {
	storyRoots = {
		Root.stories.hoarcekat,
	},
	-- Packages are included for Hoarcekat to ensure the rendering logic does
	-- _not_ attempt to render the stories with them.
	packages = {
		Roact = Roact,
	},
}
