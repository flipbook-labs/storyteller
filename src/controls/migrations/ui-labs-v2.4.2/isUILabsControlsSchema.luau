local t = require("@pkg/t")

local isUILabsControlsSchema = t.map(
	t.string,
	t.interface({
		ControlValue = t.any,
	})
)

return isUILabsControlsSchema
