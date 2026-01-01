local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type BooleanControl = ControlTypes.BooleanControl

local function createBooleanControl(default: boolean?): BooleanControl
	local control = {
		type = ControlType.Boolean,
		default = default,
	}

	validateControlSchema(ControlType.Boolean, control)

	return control
end

return createBooleanControl
