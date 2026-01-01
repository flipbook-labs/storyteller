local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type NumberControl = ControlTypes.NumberControl

local function createNumberControl(default: number?, range: NumberRange?, step: number?): NumberControl
	if default and range then
		assert(default >= range.Min and default <= range.Max, "default value must be within the range")
	end

	return {
		type = ControlType.Number,
		default = default,
		range = range,
		step = step,
	}
end

return createNumberControl
