local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type ControlOptions = ControlTypes.ControlOptions
type SelectControl = ControlTypes.SelectControl

local function createSelectControl(options: ControlOptions, default: string?): SelectControl
	local control: SelectControl = {
		type = ControlType.Select,
		options = options,
		default = default,
	}

	ControlTypes.SelectControl:assert(control)

	return control
end

return createSelectControl
