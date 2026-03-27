local React = require("@pkg/React")

local function ReactButton(props)
	return React.createElement("TextButton", {
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
		return React.createElement(ReactButton, {
			isDisabled = props.controls.isDisabled,
		})
	end,
}
