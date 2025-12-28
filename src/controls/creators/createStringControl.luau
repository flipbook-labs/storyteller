local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type StringControl = types.StringControl

local function createStringControl(default: string?, placeholder: string?): StringControl
	return {
		control = ControlType.String,
		default = default,
		placeholder = placeholder,
	}
end

return createStringControl
