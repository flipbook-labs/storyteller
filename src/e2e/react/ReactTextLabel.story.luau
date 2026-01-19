local React = require("@pkg/React")

local ReactTextLabel = require("./ReactTextLabel")

return {
	story = function()
		return React.createElement(ReactTextLabel)
	end,
}
