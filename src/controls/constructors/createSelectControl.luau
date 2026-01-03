local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type SelectControl = ControlTypes.SelectControl
type Mapping = ControlTypes.Mapping

local function createSelectControl(options: { string }, default: string?, mapping: Mapping?): SelectControl
	local control: SelectControl = {
		type = ControlType.Select,
		options = options,
		default = default,
		mapping = mapping,
	}

	ControlTypes.SelectControl:assert(control)

	return control
end

return createSelectControl
