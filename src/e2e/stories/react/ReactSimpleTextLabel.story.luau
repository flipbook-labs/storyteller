local React = require("@pkg/React")

local function ReactTextLabel()
	return React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.BuilderSans,
		Text = "Hello World",
		TextColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 16,
	}, {
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
		}),
	})
end

return {
	story = function()
		return React.createElement(ReactTextLabel)
	end,
}
