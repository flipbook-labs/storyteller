local Vide = require("@pkg/Vide")

local function VideButton(props: {
	isDisabled: () -> boolean,
})
	return Vide.create("TextButton")({
		AutomaticSize = Enum.AutomaticSize.XY,
		Font = Enum.Font.BuilderSans,
		Text = function()
			return if props.isDisabled() then "Disabled" else "Enabled"
		end,
		TextSize = 16,
	})
end

return VideButton
