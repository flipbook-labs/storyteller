local Fusion = require("@pkg/Fusion")

local New = Fusion.New

type StateObject<T> = Fusion.StateObject<T>

local function FusionButton(props: {
	isDisabled: StateObject<boolean>,
})
	return New("TextButton")({
		Text = if props.isDisabled:get() then "Disabled" else "Enabled",
	})
end

return FusionButton
