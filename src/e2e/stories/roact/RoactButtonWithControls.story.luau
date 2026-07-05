local Roact = require("@pkg/Roact")

local function RoactButton(props)
	return Roact.createElement("TextButton", {
		Text = if props.isDisabled then "Disabled" else "Enabled",
	})
end

local controls = {
	isDisabled = false,
}

type Props = {
	controls: typeof(controls),
}

return {
	controls = controls,
	story = function(props: Props)
		return Roact.createElement(RoactButton, {
			isDisabled = props.controls.isDisabled,
		})
	end,
}
