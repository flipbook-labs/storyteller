local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type ObjectControl = ControlTypes.ObjectControl

local function createObjectControl(default: Instance?): ObjectControl
	local control: ObjectControl = {
		type = ControlType.Object,
		default = default,
	}

	ControlTypes.ObjectControl:assert(control)

	return control
end

return createObjectControl
