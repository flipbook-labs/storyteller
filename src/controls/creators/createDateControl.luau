local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type DateControl = ControlTypes.DateControl

local function createDateControl(default: DateTime?): DateControl
	return {
		control = ControlType.Date,
		default = default,
	}
end

return createDateControl
