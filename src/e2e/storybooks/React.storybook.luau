local Root = script:FindFirstAncestor("e2e")

local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

return {
	storyRoots = {
		Root.stories.react,
	},
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
