local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type ColorControl = ControlTypes.ColorControl

local function createColorControl(default: Color3?): ColorControl
	local control: ColorControl = {
		type = ControlType.Color,
		default = default,
	}

	ControlTypes.ColorControl:assert(control)

	return control
end

return createColorControl
