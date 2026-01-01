local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type StringControl = ControlTypes.StringControl

local function createStringControl(default: string?): StringControl
	return {
		type = ControlType.String,
		default = default,
	}
end

return createStringControl
