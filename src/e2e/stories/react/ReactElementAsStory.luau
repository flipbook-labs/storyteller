local React = require("@pkg/React")

local function ReactTextLabel()
	return React.createElement("TextLabel", {
		Text = "Hello, World!",
	})
end

return {
	story = React.createElement(ReactTextLabel),
}
