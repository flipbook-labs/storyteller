local React = require("@pkg/React")

local controls = {
	isDisabled = false,
}

type Props = {
	controls: typeof(controls),
}

return {
	name = "Multiple React stories",
	controls = controls,
	stories = {
		{
			id = "primary",
			name = "Primary",
			story = function(props: Props)
				return React.createElement("TextButton", {
					Text = if props.controls.isDisabled then "Disabled" else "Enabled",
				})
			end,
		},
		{
			id = "secondary",
			name = "Secondary",
			story = function(props: Props)
				return React.createElement("TextButton", {
					Text = if props.controls.isDisabled then "Disabled" else "Enabled",
				})
			end,
		},
	},
}
