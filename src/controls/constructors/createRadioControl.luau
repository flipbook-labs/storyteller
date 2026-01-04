local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type RadioControl = ControlTypes.RadioControl
type Mapping = ControlTypes.Mapping

local function createRadioControl(options: { string }, default: string?, mapping: Mapping?): RadioControl
	local control: RadioControl = {
		type = ControlType.Radio,
		options = options,
		default = default,
		mapping = mapping,
	}

	ControlTypes.RadioControl:assert(control)

	return control
end

return createRadioControl
