local FusionButton = require("./FusionButton")

return {
	controls = {
		isDisabled = false,
	},
	story = function(props)
		return FusionButton({
			isDisabled = props.controls.isDisabled,
		})
	end,
}
