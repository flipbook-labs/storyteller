local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type RadioControl = ControlTypes.RadioControl
type Mapping = ControlTypes.Mapping

local function createRadioControl(options: { string }, default: string?, mapping: Mapping?): RadioControl
	return {
		control = ControlType.Radio,
		options = options,
		default = default,
		mapping = mapping,
	}
end

return createRadioControl
