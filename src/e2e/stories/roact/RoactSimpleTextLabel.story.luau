local Roact = require("@pkg/Roact")

local function RoactTextLabel()
	return Roact.createElement("TextLabel", {
		Text = "Hello, World!",
	})
end

return {
	story = RoactTextLabel,
}
