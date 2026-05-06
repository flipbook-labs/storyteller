local Roact = require("@pkg/Roact")

local function HoarcekatRoactComponent()
	return Roact.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.BuilderSans,
		Text = "Hello World",
		TextColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 16,
	}, {
		Padding = Roact.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
		}),
	})
end

return function(target: Instance)
	local root = Roact.createElement(HoarcekatRoactComponent)
	local tree = Roact.mount(root, target)

	return function()
		Roact.unmount(tree)
	end
end
