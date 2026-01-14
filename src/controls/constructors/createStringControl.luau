local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StringControl = ControlTypes.StringControl

local function createStringControl(default: string?): StringControl
	local control: StringControl = {
		type = ControlType.String,
		default = default,
	}

	ControlTypes.StringControl:assert(control)

	return control
end

return createStringControl
