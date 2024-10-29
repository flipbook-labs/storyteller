local React = require("@pkg/React")
local ReactCounter = require("./ReactCounter")

return {
	summary = "A simple counter that increments every second. This is a copy of the Counter component, but written with React",
	story = function()
		return React.createElement(ReactCounter)
	end,
}
