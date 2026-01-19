local Fusion = require("@pkg/Fusion")

local New = Fusion.New
local Computed = Fusion.Computed

type StateObject<T> = Fusion.StateObject<T>

local function FusionButton(props: {
	isDisabled: StateObject<boolean>,
})
	return New("TextButton")({
		Text = Computed(function()
			return if props.isDisabled:get() then "Disabled" else "Enabled"
		end),
	})
end

return FusionButton
