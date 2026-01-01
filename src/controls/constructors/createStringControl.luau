local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type StringControl = ControlTypes.StringControl

local function createStringControl(default: string?): StringControl
	local control = {
		type = ControlType.String,
		default = default,
	}

	validateControlSchema(ControlType.String, control)

	return control
end

return createStringControl
