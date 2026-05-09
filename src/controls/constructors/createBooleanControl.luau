local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type BooleanControl = ControlTypes.BooleanControl

local function createBooleanControl(default: boolean?): BooleanControl
	local control: BooleanControl = {
		type = ControlType.Boolean,
		default = default,
	}

	ControlTypes.BooleanControl:assert(control)

	return control
end

return createBooleanControl
