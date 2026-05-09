local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type DateControl = ControlTypes.DateControl

local function createDateControl(default: DateTime?): DateControl
	local control: DateControl = {
		type = ControlType.Date,
		default = default,
	}

	ControlTypes.DateControl:assert(control)

	return control
end

return createDateControl
