local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type NumberControl = ControlTypes.NumberControl

local function createNumberControl(default: number?, range: NumberRange?, step: number?): NumberControl
	local control: NumberControl = {
		type = ControlType.Number,
		default = default,
		range = range,
		step = step,
	}

	ControlTypes.NumberControl:assert(control)

	return control
end

return createNumberControl
