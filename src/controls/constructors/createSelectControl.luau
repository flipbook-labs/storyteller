local ControlType = require("@root/controls/enums/ControlType")
local ControlTypes = require("@root/controls/ControlTypes")

type SelectControl = ControlTypes.SelectControl
type SelectOptions = ControlTypes.SelectOptions
type StoryControlValue = ControlTypes.StoryControlValue

local function createSelectControl(items: { StoryControlValue }, options: SelectOptions?): SelectControl
	local control: SelectControl = {
		type = ControlType.Select,
		items = items,
	}

	if options then
		for k, v in options do
			control[k] = v
		end
	end

	ControlTypes.SelectControl:assert(control)

	return control
end

return createSelectControl
