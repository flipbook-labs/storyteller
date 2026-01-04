local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type CheckControl = ControlTypes.CheckControl
type Mapping = ControlTypes.Mapping

local function createCheckControl(options: { string }, default: { string }?, mapping: Mapping?): CheckControl
	local control: CheckControl = {
		type = ControlType.Check,
		options = options,
		default = default,
		mapping = mapping,
	}

	ControlTypes.CheckControl:assert(control)

	return control
end

return createCheckControl
