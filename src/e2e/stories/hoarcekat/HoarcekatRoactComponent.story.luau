local Roact = require("@pkg/Roact")

local function HoarcekatRoactComponent()
	return Roact.createElement("TextLabel", {
		Text = "Hoarcekat Story",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Size = UDim2.fromOffset(300, 100),
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
	local tree = Roact.mount(Roact.createElement(HoarcekatRoactComponent), nil, target)

	return function()
		Roact.unmount(tree)
	end
end
