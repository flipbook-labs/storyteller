local React = require("@pkg/React")

local function ReactTextLabel()
	return React.createElement("TextLabel", {
		Text = "Hello, World!",
	})
end

return {
	story = function()
		return React.createElement(ReactTextLabel)
	end,
}
