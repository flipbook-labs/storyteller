local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type ControlOptions = ControlTypes.ControlOptions
type MultiSelectControl = ControlTypes.MultiSelectControl

local function createMultiSelectControl(options: ControlOptions, default: { string }?): MultiSelectControl
	local control: MultiSelectControl = {
		type = ControlType.MultiSelect,
		options = options,
		default = default,
	}

	ControlTypes.MultiSelectControl:assert(control)

	return control
end

return createMultiSelectControl
