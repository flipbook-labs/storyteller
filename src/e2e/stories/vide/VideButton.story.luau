local VideButton = require("./VideButton")

return {
	controls = {
		isDisabled = false,
	},
	story = function(props)
		return VideButton({
			isDisabled = props.controls.isDisabled,
		})
	end,
}
