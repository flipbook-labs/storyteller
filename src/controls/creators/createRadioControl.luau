local ControlType = require("@root/controls/enums/ControlType")
local types = require("@root/controls/types")

type RadioControl = types.RadioControl

local function createRadioControl<T>(options: { T }): RadioControl
	return {
		control = ControlType.Radio,
		options = options,
	}
end

return createRadioControl
