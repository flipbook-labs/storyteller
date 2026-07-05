local Vide = require("@pkg/Vide")

local function VideTextLabel()
	return Vide.create("TextLabel")({
		AutomaticSize = Enum.AutomaticSize.XY,
		Font = Enum.Font.BuilderSans,
		Text = "Hello World",
		TextSize = 16,
	})
end

return VideTextLabel
