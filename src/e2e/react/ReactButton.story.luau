local React = require("@pkg/React")

local ReactButton = require("./ReactButton")

return {
	controls = {
		isDisabled = false,
	},
	story = function(props)
		return React.createElement(ReactButton, {
			isDisabled = props.controls.isDisabled,
		})
	end,
}
