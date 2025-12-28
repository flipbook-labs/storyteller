local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type DateControl = types.DateControl

local function createDateControl(default: DateTime?): DateControl
	return {
		control = ControlType.Date,
		default = default,
	}
end

return createDateControl
