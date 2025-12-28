local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type BooleanControl = types.BooleanControl

local function createBooleanControl(default: boolean): BooleanControl
	return {
		control = ControlType.Boolean,
		default = default,
	}
end

return createBooleanControl
