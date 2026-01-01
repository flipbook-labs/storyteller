local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type NumberControl = ControlTypes.NumberControl

local function createNumberControl(default: number?, range: NumberRange?, step: number?): NumberControl
	local control = {
		type = ControlType.Number,
		default = default,
		range = range,
		step = step,
	}

	validateControlSchema(ControlType.Number, control)

	return control
end

return createNumberControl
