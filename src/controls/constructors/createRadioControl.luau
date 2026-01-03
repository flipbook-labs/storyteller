local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type ControlOptions = ControlTypes.ControlOptions
type RadioControl = ControlTypes.RadioControl

local function createRadioControl(options: ControlOptions, default: string?): RadioControl
	local control: RadioControl = {
		type = ControlType.Radio,
		options = options,
		default = default,
	}

	ControlTypes.RadioControl:assert(control)

	return control
end

return createRadioControl
