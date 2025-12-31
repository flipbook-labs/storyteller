local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type ColorControl = ControlTypes.ColorControl

local function createColorControl(default: Color3?): ColorControl
	return {
		control = ControlType.Color,
		default = default,
	}
end

return createColorControl
