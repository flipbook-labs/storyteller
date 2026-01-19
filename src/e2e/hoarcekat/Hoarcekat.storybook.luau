local Roact = require("@pkg/Roact")

return {
	storyRoots = {
		script.Parent,
	},
	-- Packages are included for Hoarcekat to ensure the rendering logic does
	-- _not_ attempt to render the stories with them.
	packages = {
		Roact = Roact,
	},
}
