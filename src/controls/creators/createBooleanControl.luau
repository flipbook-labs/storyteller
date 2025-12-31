local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type BooleanControl = ControlTypes.BooleanControl

local function createBooleanControl(default: boolean): BooleanControl
	return {
		control = ControlType.Boolean,
		default = default,
	}
end

return createBooleanControl
