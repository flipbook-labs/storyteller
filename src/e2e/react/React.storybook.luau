local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

return {
	storyRoots = {
		script.Parent,
	},
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
