local Fusion = require("@pkg/Fusion")

local New = Fusion.New
local Children = Fusion.Children

local function FusionTextLabel()
	return New("TextLabel")({
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.BuilderSans,
		Text = "Hello World",
		TextColor3 = Color3.fromRGB(15, 15, 15),
		TextSize = 16,
		[Children] = New("UIPadding")({
			PaddingTop = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
		}),
	})
end

return FusionTextLabel
