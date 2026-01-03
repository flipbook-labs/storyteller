local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type CheckControl = ControlTypes.CheckControl
type ControlOptions = ControlTypes.ControlOptions

local function createCheckControl(options: ControlOptions, default: { string }?): CheckControl
	local control: CheckControl = {
		type = ControlType.Check,
		options = options,
		default = default,
	}

	ControlTypes.CheckControl:assert(control)

	return control
end

return createCheckControl
