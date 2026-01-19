local Fusion = require("@pkg/Fusion")

local New = Fusion.New

local function FusionTextLabel()
	return New("TextLabel")({
		Text = "Hello World",
	})
end

return FusionTextLabel
