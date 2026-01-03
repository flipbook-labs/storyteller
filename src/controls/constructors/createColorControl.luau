local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type ColorControl = ControlTypes.ColorControl

local function createColorControl(default: Color3?): ColorControl
	local control: ColorControl = {
		type = ControlType.Color,
		default = default,
	}

	validateControlSchema(ControlType.Color, control)

	return control
end

return createColorControl
