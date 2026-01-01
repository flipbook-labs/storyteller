local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")
local validateControlSchema = require("@root/controls/parsing/validateControlSchema")

type RadioControl = ControlTypes.RadioControl
type Mapping = ControlTypes.Mapping

local function createRadioControl(options: { string }, default: string?, mapping: Mapping?): RadioControl
	local control = {
		type = ControlType.Radio,
		options = options,
		default = default,
		mapping = mapping,
	}

	validateControlSchema(ControlType.Radio, control)

	return control
end

return createRadioControl
