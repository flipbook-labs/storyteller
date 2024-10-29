local React = require("@pkg/React")
local ReactButton = require("./ReactButton")

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
