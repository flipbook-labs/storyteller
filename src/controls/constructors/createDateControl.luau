local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type DateControl = ControlTypes.DateControl

local function createDateControl(default: DateTime?): DateControl
	local control = {
		type = ControlType.Date,
		default = default,
	}

	validateControlSchema(ControlType.Date, control)

	return control
end

return createDateControl
