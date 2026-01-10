local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type CheckControl = ControlTypes.CheckControl
type CheckOptions = ControlTypes.CheckOptions
type StoryControlValue = ControlTypes.StoryControlValue

local function createCheckControl(items: { StoryControlValue }, options: CheckOptions?): CheckControl
	local control: CheckControl = {
		type = ControlType.Check,
		items = items,
	}

	if options then
		for k, v in options do
			control[k] = v
		end
	end

	ControlTypes.CheckControl:assert(control)

	return control
end

return createCheckControl
