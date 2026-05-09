local Vide = require("@pkg/Vide")

local function VideButton(props: {
	isDisabled: () -> boolean,
})
	return Vide.create("TextButton")({
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.BuilderSans,
		Text = function()
			return if props.isDisabled() then "Disabled" else "Enabled"
		end,
		TextColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 16,
		Vide.create("UIPadding")({
			PaddingTop = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
		}),
	})
end

return VideButton
