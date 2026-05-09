local gt = require("@pkg/GreenTea")

local UILabsControlsSchema = gt.dictionary(
	gt.string(),
	gt.struct({
		ControlValue = gt.any(),
	})
)

local function isUILabsControlsSchema(...)
	return gt.build(UILabsControlsSchema):matches(...)
end

return isUILabsControlsSchema
