local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type ColorControl = types.ColorControl
type Mapping = types.Mapping

local function createColorControl(default: Color3?): ColorControl
	return {
		control = ControlType.Color,
		default = default,
	}
end

return createColorControl
